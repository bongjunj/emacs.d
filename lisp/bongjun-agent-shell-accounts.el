;;; bongjun-agent-shell-accounts.el --- Codex account profiles -*- lexical-binding: t; -*-

;;; Commentary:
;; Each shell captures its account's CODEX_HOME in its client factory, so
;; reconnects and restarts keep the same credentials.  Codex handles login
;; and token refresh.  No credentials are read or copied by this module.

;;; Code:

(require 'agent-shell)
(require 'agent-shell-openai)
(require 'cl-lib)
(require 'comint)
(require 'map)
(require 'seq)
(require 'subr-x)

(defgroup bongjun-agent-shell-accounts nil
  "Named Codex accounts in agent-shell."
  :group 'agent-shell)

(defcustom bongjun/agent-shell-accounts
  '(("bongjun-work" . "~/.local/share/codex-accounts/bongjun-work")
    ("bongjun-research" . "~/.local/share/codex-accounts/bongjun-research"))
  "Account names and their separate Codex state directories.
Directories are created on first use.  Each has its own login, config,
sessions, and skills; the existing ~/.codex directory is independent."
  :type '(alist :key-type string :value-type directory)
  :group 'bongjun-agent-shell-accounts)

(defcustom bongjun/agent-shell-current-account nil
  "Account used when opening a shell outside an existing account shell.
If nil or no longer configured, use the first entry in
`bongjun/agent-shell-accounts'.  Switching accounts updates this value."
  :type '(choice (const :tag "First configured account" nil) string)
  :group 'bongjun-agent-shell-accounts)

(defun bongjun/agent-shell--default-account ()
  "Return the selected account, or the first configured account."
  (or (car (assoc bongjun/agent-shell-current-account
                  bongjun/agent-shell-accounts))
      (caar bongjun/agent-shell-accounts)
      (user-error "Configure at least one entry in bongjun/agent-shell-accounts")))

(defun bongjun/agent-shell--account-home (account)
  "Return the local Codex home for ACCOUNT, or signal a user error."
  (let ((home (cdr (assoc account bongjun/agent-shell-accounts))))
    (unless home
      (user-error "Unknown Codex account: %s" account))
    (when (file-remote-p home)
      (user-error "Codex account homes must be local"))
    ;; Use a local base even if called from a TRAMP buffer.
    (directory-file-name (expand-file-name home "~/"))))

(defun bongjun/agent-shell--check-local ()
  "Require a local shell without a container command prefix."
  (when (or (file-remote-p default-directory) agent-shell-command-prefix)
    (user-error "Codex account profiles require a local shell without a command prefix")))

(defun bongjun/agent-shell--ensure-account-home (home)
  "Create HOME privately if it does not exist."
  (unless (file-directory-p home)
    (make-directory home t)
    (set-file-modes home #o700)))

(defun bongjun/agent-shell--account-environment (home)
  "Build an environment for HOME using the configured Codex executable."
  (let* ((process-environment
          (append agent-shell-openai-codex-environment process-environment))
         (codex (or (getenv "CODEX_PATH") (executable-find "codex"))))
    (unless (and codex (not (string-empty-p codex)))
      (user-error "Install codex or set CODEX_PATH before using account profiles"))
    (append
     (list (concat "CODEX_HOME=" home)
           (concat "CODEX_SQLITE_HOME=" home)
           (concat "CODEX_PATH=" codex)
           ;; Bare names remove inherited credentials from child environments.
           "OPENAI_API_KEY" "CODEX_API_KEY" "CODEX_ACCESS_TOKEN")
     (seq-remove
      (lambda (entry)
        (member (car (split-string entry "="))
                '("CODEX_HOME" "CODEX_SQLITE_HOME" "CODEX_PATH"
                  "OPENAI_API_KEY" "CODEX_API_KEY" "CODEX_ACCESS_TOKEN")))
      agent-shell-openai-codex-environment))))

(defun bongjun/agent-shell-make-codex-config (&optional account)
  "Create a Codex configuration permanently bound to ACCOUNT.
ACCOUNT defaults to the selected account, or the first configured one."
  (let* ((account (or account (bongjun/agent-shell--default-account)))
         (home (bongjun/agent-shell--account-home account))
         (environment (bongjun/agent-shell--account-environment home))
         (command (copy-sequence agent-shell-openai-codex-acp-command))
         (config (agent-shell-openai-make-codex-config))
         (client-maker (map-elt config :client-maker))
         (label (format "Codex [%s]" account)))
    ;; Preserve the codex identifier for limits and other provider integrations.
    (setf (map-elt config :buffer-name) label
          (map-elt config :mode-line-name) label
          (map-elt config :bongjun-account) account
          (map-elt config :bongjun-codex-home) home
          (map-elt config :client-maker)
          (lambda (buffer)
            (with-current-buffer buffer
              (bongjun/agent-shell--check-local)
              (bongjun/agent-shell--ensure-account-home home)
              (let ((agent-shell-openai-authentication
                     (agent-shell-openai-make-authentication :login t))
                    (agent-shell-openai-codex-environment environment)
                    (agent-shell-openai-codex-acp-command command))
                (funcall client-maker buffer)))))
    config))

(defun bongjun/agent-shell--current-account-shell ()
  "Return the current shell or viewport's shell, if it has an account."
  (when (derived-mode-p 'agent-shell-mode
                        'agent-shell-viewport-view-mode
                        'agent-shell-viewport-edit-mode)
    (when-let* ((buffer (agent-shell-shell-buffer :no-create t :no-error t))
                ((map-nested-elt (buffer-local-value 'agent-shell--state buffer)
                                 '(:agent-config :bongjun-account))))
      buffer)))

(defun bongjun/agent-shell--read-account ()
  "Read a configured account, defaulting to the current shell's account."
  (completing-read
   "Codex account: " bongjun/agent-shell-accounts nil t nil nil
   (or (when-let* ((buffer (bongjun/agent-shell--current-account-shell)))
         (map-nested-elt (buffer-local-value 'agent-shell--state buffer)
                         '(:agent-config :bongjun-account)))
       (bongjun/agent-shell--default-account))))

(defun bongjun/agent-shell--open-account (account &optional new-shell)
  "Show ACCOUNT's shell for this project, creating one if needed.
With NEW-SHELL, always create a new shell."
  (let* ((current (bongjun/agent-shell--current-account-shell))
         (cwd (if current
                  (with-current-buffer current (agent-shell-cwd))
                (agent-shell-cwd)))
         (default-directory cwd)
         (config (bongjun/agent-shell-make-codex-config account))
         (home (map-elt config :bongjun-codex-home)))
    (bongjun/agent-shell--check-local)
    (let ((buffer
           (unless new-shell
             (seq-find
              (lambda (buffer)
                (let ((existing (map-elt
                                 (buffer-local-value 'agent-shell--state buffer)
                                 :agent-config)))
                  (and (equal (map-elt existing :bongjun-account) account)
                       (equal (map-elt existing :bongjun-codex-home) home))))
              (agent-shell-project-buffers cwd)))))
      (if buffer
          (if agent-shell-prefer-viewport-interaction
              (agent-shell-viewport--show-buffer :shell-buffer buffer)
            (pop-to-buffer buffer agent-shell-display-action))
        (setq buffer (agent-shell-start :config config)))
      (setq bongjun/agent-shell-current-account account)
      buffer)))

;;;###autoload
(defun bongjun/agent-shell (&optional new-shell)
  "Open the current Codex account's shell for this project.
Inside an account shell, keep using that shell's account.
With a prefix argument NEW-SHELL, start another shell for the account."
  (interactive "P")
  (bongjun/agent-shell--open-account
   (or (when-let* ((buffer (bongjun/agent-shell--current-account-shell)))
         (map-nested-elt (buffer-local-value 'agent-shell--state buffer)
                         '(:agent-config :bongjun-account)))
       (bongjun/agent-shell--default-account))
   new-shell))

;;;###autoload
(defun bongjun/agent-shell-switch-account (account &optional new-shell)
  "Select ACCOUNT and open its shell for the current project.
With a prefix argument NEW-SHELL, always start another shell."
  (interactive (list (bongjun/agent-shell--read-account) current-prefix-arg))
  (bongjun/agent-shell--open-account account new-shell))

;;;###autoload
(defun bongjun/agent-shell-account-login (account &optional method)
  "Run Codex login for ACCOUNT in a dedicated comint buffer.
METHOD is `browser' (the default) or `device'.  Interactively, a
prefix argument selects device login.  Follow its URL and code on
any device."
  (interactive (list (bongjun/agent-shell--read-account)
                     (if current-prefix-arg 'device 'browser)))
  (bongjun/agent-shell--check-local)
  (unless (memq method '(nil device browser))
    (user-error "Unknown Codex login method: %s" method))
  (let* ((home (bongjun/agent-shell--account-home account))
         (environment (bongjun/agent-shell--account-environment home))
         (process-environment (append environment process-environment))
         (codex (getenv "CODEX_PATH"))
         (name (format "Codex login [%s]" account))
         (buffer (get-buffer-create (format "*%s*" name))))
    (bongjun/agent-shell--ensure-account-home home)
    (if (comint-check-proc buffer)
        (progn
          (pop-to-buffer buffer)
          (message "A Codex login for %s is already running" account))
      (let ((default-directory (file-name-as-directory home)))
        (apply #'make-comint-in-buffer name buffer codex nil
               (if (eq method 'device)
                   '("login" "--device-auth")
                 '("login"))))
      (pop-to-buffer buffer)
      (message (if (eq method 'device)
                   "Follow the device login instructions for %s in the buffer"
                 "Complete Codex login for %s in your browser")
               account))))

(defun bongjun/agent-shell--account-header (original state &rest args)
  "Show STATE's configured profile name in ORIGINAL's header model."
  (let ((model (apply original state args))
        (account (map-nested-elt state '(:agent-config :bongjun-account))))
    (when account
      (setf (map-elt model :buffer-name)
            (propertize (format "Codex · Account: %s" account)
                        'help-echo (map-nested-elt
                                    state '(:agent-config :bongjun-codex-home)))))
    model))

(advice-add 'agent-shell--make-header-model :around
            #'bongjun/agent-shell--account-header)

(defun bongjun/agent-shell--authentication-hint (original &rest args)
  "Preserve ORIGINAL request handling and explain account login failures.
ARGS are the keyword arguments to `agent-shell--send-request'."
  (let* ((state (plist-get args :state))
         (buffer (plist-get args :buffer))
         (account (map-nested-elt state '(:agent-config :bongjun-account)))
         (on-failure (plist-get args :on-failure)))
    (when account
      (setq args
            (plist-put
             args :on-failure
             (lambda (acp-error raw-message)
               (unwind-protect
                   (when on-failure (funcall on-failure acp-error raw-message))
                 (when (and (buffer-live-p buffer)
                            (string-match-p
                             "[Aa]uthentication required"
                             (or (map-elt acp-error 'message) "")))
                   (with-current-buffer buffer
                     (agent-shell--update-bootstrapping-fragment
                      :state state :block-id "bongjun-account-login"
                      :body (agent-shell--make-boxed-message
                             :text (format "Sign in to Codex account %s with C-c a l, then start a new shell with C-c a n." account))))))))))
    (apply original args)))

(unless (advice-member-p #'bongjun/agent-shell--authentication-hint
                         'agent-shell--send-request)
  (advice-add 'agent-shell--send-request :around
              #'bongjun/agent-shell--authentication-hint))

(defvar bongjun/agent-shell--base-agent-configs agent-shell-agent-configs
  "Agent configuration source before installing the account integration.")

(defun bongjun/agent-shell--agent-configs ()
  "Use account profiles for the standard Codex configuration factory.
Resolve profiles on demand so Customize changes apply to new shells."
  (mapcar
   (lambda (entry)
     (if (eq entry #'agent-shell-openai-make-codex-config)
         #'bongjun/agent-shell-make-codex-config
       entry))
   (if (functionp bongjun/agent-shell--base-agent-configs)
       (funcall bongjun/agent-shell--base-agent-configs)
     bongjun/agent-shell--base-agent-configs)))

;; Native new shells resolve the selected account; restarts retain their config.
(setq agent-shell-agent-configs #'bongjun/agent-shell--agent-configs)

(provide 'bongjun-agent-shell-accounts)
;;; bongjun-agent-shell-accounts.el ends here
