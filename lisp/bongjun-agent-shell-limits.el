;;; bongjun-agent-shell-limits.el --- Codex account limits -*- lexical-binding: t; -*-

;; Query the documented app-server account API, without starting a thread.
;; Kept outside elpa so package upgrades preserve this integration.

(require 'agent-shell)
(require 'json)
(require 'map)
(require 'subr-x)

(defvar bongjun/agent-shell-limits-command '("codex" "app-server")
  "Local Codex app-server command.  CODEX_PATH overrides its executable.
Use the same Codex installation and CODEX_HOME as codex-acp.")
(defvar bongjun/agent-shell-limits-interval 300
  "Seconds between account limit refreshes.")

(defvar-local bongjun/agent-shell-limits--snapshot nil)
(defvar-local bongjun/agent-shell-limits--updated nil)
(defvar-local bongjun/agent-shell-limits--attempted 0)
(defvar-local bongjun/agent-shell-limits--error nil)
(defvar-local bongjun/agent-shell-limits--process nil)
(defvar-local bongjun/agent-shell-limits--timer nil)
(defvar-local bongjun/agent-shell-limits--subscription nil)

(defun bongjun/agent-shell-limits--codex-p ()
  "Whether this is a local Codex shell using ChatGPT authentication."
  (and (derived-mode-p 'agent-shell-mode)
       (eq (map-nested-elt agent-shell--state '(:agent-config :identifier))
           'codex)
       (not (file-remote-p default-directory))
       (not agent-shell-command-prefix)
       (map-elt agent-shell-openai-authentication :login)))

(defun bongjun/agent-shell-limits--windows (snapshot)
  "Return the five-hour and weekly windows in SNAPSHOT, in that order."
  (let ((windows (list (map-elt snapshot 'primary)
                       (map-elt snapshot 'secondary))))
    (delq nil
          (mapcar (lambda (minutes)
                    (seq-find (lambda (window)
                                (and (equal (map-elt window 'windowDurationMins)
                                            minutes)
                                     (numberp (map-elt window 'usedPercent))))
                              windows))
                  '(300 10080)))))

(defun bongjun/agent-shell-limits--indicator ()
  "Format cached limits and reset times, with full dates in the tooltip."
  (let ((windows (bongjun/agent-shell-limits--windows
                  bongjun/agent-shell-limits--snapshot)))
    (if (not windows)
        (propertize (if bongjun/agent-shell-limits--error
                        "Limits unavailable" "Limits…")
                    'face 'shadow
                    'help-echo (or bongjun/agent-shell-limits--error
                                   "Reading Codex account limits"))
      (let* ((stale (or bongjun/agent-shell-limits--error
                        (and bongjun/agent-shell-limits--updated
                             (> (- (float-time) bongjun/agent-shell-limits--updated)
                                (* 2 bongjun/agent-shell-limits-interval)))))
             (tooltip
              (string-join
               (append
                (list (format "Codex account limits: remaining%s"
                              (if stale " (cached; refresh needed)" "")))
                (mapcar
                 (lambda (window)
                   (format "%s resets %s"
                           (if (= (map-elt window 'windowDurationMins) 300)
                               "5h" "Weekly")
                           (if-let* ((reset (map-elt window 'resetsAt))
                                     ((numberp reset)))
                               (format-time-string "%a %b %d %H:%M %Z"
                                                   (seconds-to-time reset))
                             "at an unknown time")))
                 windows)
                (when bongjun/agent-shell-limits--updated
                  (list (format-time-string
                         "Updated %H:%M:%S"
                         (seconds-to-time bongjun/agent-shell-limits--updated))))
                (when bongjun/agent-shell-limits--error
                  (list bongjun/agent-shell-limits--error)))
               "\n")))
        (concat
         (mapconcat
          (lambda (window)
            (let* ((left (max 0 (min 100 (- 100 (map-elt window 'usedPercent)))))
                   (reset (map-elt window 'resetsAt))
                   (weekly (= (map-elt window 'windowDurationMins) 10080))
                   (expired (and (numberp reset) (<= reset (float-time)))))
              (propertize
               (format "%s: %s%s" (if weekly "Weekly" "5h")
                       ;; Header strings use mode-line percent escaping.
                       (if expired "…" (format "%.0f%%%%" left))
                       (if (and (numberp reset) (not expired))
                           (format-time-string
                            (if weekly " ↻ %a %H:%M" " ↻ %H:%M")
                            (seconds-to-time reset))
                         ""))
               'face (cond ((or stale expired) 'shadow)
                           ((<= left 10) 'error)
                           ((<= left 20) 'warning)
                           (t 'success))
               'help-echo tooltip)))
          windows " · ")
         (when stale (propertize " *" 'face 'shadow 'help-echo tooltip)))))))

(defun bongjun/agent-shell-limits--header (original state &rest args)
  "Add limits to ORIGINAL's header model for the shell in STATE and ARGS."
  (let ((model (apply original state args)))
    (when-let* ((buffer (map-elt state :buffer))
                ((buffer-live-p buffer))
                (indicator (with-current-buffer buffer
                             (when (bongjun/agent-shell-limits--codex-p)
                               (bongjun/agent-shell-limits--indicator)))))
      ;; Reuse the usage segment so text, SVG, and viewport headers agree.
      (setf (map-elt model :context-indicator)
            (string-join (delq nil (list (map-elt model :context-indicator)
                                        indicator)) " ➤ ")))
    model))

(defun bongjun/agent-shell-limits--send (process message)
  "Send a newline-delimited JSON MESSAGE to PROCESS."
  (process-send-string process (concat (json-serialize message) "\n")))

(defun bongjun/agent-shell-limits--finish (process &optional error-text)
  "Finish PROCESS's query and record ERROR-TEXT, if any."
  (when-let* ((timeout (process-get process 'timeout)))
    (cancel-timer timeout))
  (when-let* ((buffer (process-get process 'shell))
              ((buffer-live-p buffer)))
    (with-current-buffer buffer
      (when (eq process bongjun/agent-shell-limits--process)
        (setq bongjun/agent-shell-limits--process nil
              bongjun/agent-shell-limits--error error-text)
        (when (derived-mode-p 'agent-shell-mode)
          (agent-shell--update-header-and-mode-line)))))
  (when (process-live-p process)
    (delete-process process))
  (when-let* ((stderr (process-get process 'stderr))
              ((buffer-live-p stderr)))
    (kill-buffer stderr)))

(defun bongjun/agent-shell-limits--receive (process message)
  "Handle one JSON-RPC MESSAGE from PROCESS."
  (let ((id (map-elt message 'id))
        (result (map-elt message 'result)))
    (cond
     ((map-elt message 'error)
      (bongjun/agent-shell-limits--finish process "Codex account query failed"))
     ((equal id 1)
      (bongjun/agent-shell-limits--send process '((method . "initialized")))
      (bongjun/agent-shell-limits--send
       process '((id . 2) (method . "account/rateLimits/read"))))
     ((equal id 2)
      (let* ((buckets (map-elt result 'rateLimitsByLimitId))
             (snapshot (if buckets (map-elt buckets 'codex)
                         (map-elt result 'rateLimits)))
             (buffer (process-get process 'shell)))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (setq bongjun/agent-shell-limits--snapshot snapshot
                  bongjun/agent-shell-limits--updated (float-time))))
        (bongjun/agent-shell-limits--finish
         process (unless (bongjun/agent-shell-limits--windows snapshot)
                   "Codex did not report 5h or weekly limits for this account")))))))

(defun bongjun/agent-shell-limits--filter (process output)
  "Parse complete JSON lines from PROCESS's possibly fragmented OUTPUT."
  (let* ((text (concat (process-get process 'pending) output))
         (lines (split-string text "\n")))
    (process-put process 'pending (car (last lines)))
    (condition-case nil
        (dolist (line (butlast lines))
          (unless (string-empty-p line)
            (bongjun/agent-shell-limits--receive
             process (json-parse-string line :object-type 'alist
                                        :null-object nil :false-object nil))))
      (error (bongjun/agent-shell-limits--finish
              process "Unable to read the Codex account response")))))

(defun bongjun/agent-shell-limits-refresh (&optional force)
  "Refresh this Codex shell's account limits asynchronously.
Interactively, bypass the 30-second throttle with FORCE."
  (interactive (list t))
  (when (and (bongjun/agent-shell-limits--codex-p)
             (map-elt agent-shell--state :client)
             (not bongjun/agent-shell-limits--process)
             (or force (> (- (float-time) bongjun/agent-shell-limits--attempted) 30)))
    (setq bongjun/agent-shell-limits--attempted (float-time))
    (condition-case err
        (let* ((process-environment
                (append (map-nested-elt agent-shell--state
                                       '(:client :environment-variables))
                        process-environment))
               (command (if-let* ((path (getenv "CODEX_PATH")))
                            (cons path (cdr bongjun/agent-shell-limits-command))
                          bongjun/agent-shell-limits-command))
               (stderr (generate-new-buffer " *codex-account-limits-stderr*"))
               (process (condition-case err
                            (make-process
                             :name "codex-account-limits" :buffer nil :noquery t
                             :stderr stderr
                             :connection-type 'pipe :coding 'utf-8-unix
                             :command command
                             :filter #'bongjun/agent-shell-limits--filter
                             :sentinel
                             (lambda (proc _event)
                               (unless (process-live-p proc)
                                 (bongjun/agent-shell-limits--finish
                                  proc "Codex account query exited before replying"))))
                          (error (kill-buffer stderr)
                                 (signal (car err) (cdr err))))))
          (setq bongjun/agent-shell-limits--process process)
          (process-put process 'shell (current-buffer))
          (process-put process 'stderr stderr)
          (process-put process 'timeout
                       (run-at-time 20 nil #'bongjun/agent-shell-limits--finish
                                    process "Codex account query timed out"))
          (bongjun/agent-shell-limits--send
           process '((id . 1) (method . "initialize")
                     (params . ((clientInfo . ((name . "emacs_agent_shell_limits")
                                              (version . "1.0"))))))))
      (error
       (when bongjun/agent-shell-limits--process
         (bongjun/agent-shell-limits--finish
          bongjun/agent-shell-limits--process (error-message-string err)))
       (setq bongjun/agent-shell-limits--error (error-message-string err))
       (agent-shell--update-header-and-mode-line)))))

(defun bongjun/agent-shell-limits--cleanup ()
  "Stop this buffer's limit timer and outstanding query."
  (when bongjun/agent-shell-limits--subscription
    (agent-shell-unsubscribe
     :subscription bongjun/agent-shell-limits--subscription)
    (setq bongjun/agent-shell-limits--subscription nil))
  (when bongjun/agent-shell-limits--timer
    (cancel-timer bongjun/agent-shell-limits--timer)
    (setq bongjun/agent-shell-limits--timer nil))
  (when bongjun/agent-shell-limits--process
    (bongjun/agent-shell-limits--finish bongjun/agent-shell-limits--process)))

(defun bongjun/agent-shell-limits--setup ()
  "Enable limit refreshes for a local Codex shell."
  (when (and (bongjun/agent-shell-limits--codex-p)
             (not bongjun/agent-shell-limits--timer))
    (let ((buffer (current-buffer)))
      (setq bongjun/agent-shell-limits--timer
            (run-at-time 1 bongjun/agent-shell-limits-interval
                         (lambda ()
                           (when (buffer-live-p buffer)
                             (with-current-buffer buffer
                               (bongjun/agent-shell-limits-refresh)))))))
    (setq bongjun/agent-shell-limits--subscription
          (agent-shell-subscribe-to
           :shell-buffer (current-buffer)
           :on-event
           (lambda (event)
             (pcase (map-elt event :event)
               ((or 'init-finished 'turn-complete)
                (bongjun/agent-shell-limits-refresh))
               ('clean-up (bongjun/agent-shell-limits--cleanup))))))
    (add-hook 'kill-buffer-hook #'bongjun/agent-shell-limits--cleanup nil t)
    (add-hook 'change-major-mode-hook #'bongjun/agent-shell-limits--cleanup nil t)))

(advice-add 'agent-shell--make-header-model :around
            #'bongjun/agent-shell-limits--header)
(add-hook 'agent-shell-mode-hook #'bongjun/agent-shell-limits--setup)
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'agent-shell-mode)
      (bongjun/agent-shell-limits--setup))))

(provide 'bongjun-agent-shell-limits)
;;; bongjun-agent-shell-limits.el ends here
