;;; kvpn.el --- KAIST VPN commands -*- lexical-binding: t; -*-

(defvar kvpn--buffer nil
  "Buffer managing the current KVPN session.")

(defcustom kvpn-program "kvpn"
  "Path to the KVPN executable."
  :type 'string
  :group 'processes)

(defun kvpn--stop-processes (&optional detach)
  "Stop this buffer's VPN.
When DETACH is non-nil, let the VPN finish shutting down after buffer deletion."
  (when-let* ((proc (get-buffer-process (current-buffer)))
              ((process-live-p proc)))
    (unless (process-get proc 'kvpn-stopping)
      (process-put proc 'kvpn-stopping t)
      ;; Like Ctrl-C: let openconnect restore routes before closing its PTY.
      (condition-case nil
          (interrupt-process proc t)
        (error (delete-process proc)))
      (run-at-time 3 nil
                   (lambda ()
                     (when (process-live-p proc)
                       (delete-process proc)))))
    (when detach
      (set-process-buffer proc nil))))

(defun kvpn--kill-buffer ()
  "Disconnect VPN when its log buffer is killed."
  (kvpn--stop-processes t))

(defun kvpn-start ()
  "Show the running KVPN session, or start one in its log buffer."
  (interactive)
  (let* ((existing (get-process "kvpn-process"))
         (buffer (or (and (buffer-live-p kvpn--buffer) kvpn--buffer)
                     (and (process-live-p existing) (process-buffer existing))
                     (get-buffer-create "*KVPN Log*"))))
    (setq kvpn--buffer buffer)
    (pop-to-buffer buffer)
    (with-current-buffer buffer
      (add-hook 'kill-buffer-hook #'kvpn--kill-buffer nil t)
      (if (process-live-p (get-buffer-process buffer))
          (get-buffer-process buffer)
        (kvpn--launch)))))

(defun kvpn--launch ()
  "Start KVPN and handle SMS and sudo password prompts."
  (let ((proc
         (make-process
          :name "kvpn-process"
          :buffer (current-buffer)
          :command (list kvpn-program)
          ;; Required so sudo can read the Mac password interactively.
          :connection-type 'pty
          :noquery t
          :filter
          (lambda (proc output)
            (when (buffer-live-p (process-buffer proc))
              (with-current-buffer (process-buffer proc)
                (let ((inhibit-read-only t))
                  (save-excursion
                    (goto-char (point-max))
                    (insert output)))
                (set-buffer-modified-p nil)))
            (unless (process-get proc 'kvpn-stopping)
              (let ((text (downcase output)))
                (cond
                 ;; Choose the default delivery method: SMS.
                 ((string-match-p "choice \\[1\\]:" text)
                  (process-send-string proc "\n"))

                 ;; Enter the verification code received by SMS.
                 ((string-match-p "enter the code:" text)
                  (process-send-string
                   proc (concat (read-string "KAIST VPN SMS code: ") "\n")))

                 ;; Enter the local Mac account password for sudo.
                 ((string-match-p
                   "\\(\\[sudo\\] password\\|password:\\)" text)
                  (process-send-string
                   proc
                   (concat (read-passwd "Mac password for sudo: ") "\n")))))))
          :sentinel
          (lambda (_proc event)
            (message "KVPN process state: %s" (string-trim event))))))
    proc))

(defun kvpn-stop ()
  "Disconnect the VPN while keeping its log buffer."
  (interactive)
  (when (buffer-live-p kvpn--buffer)
    (with-current-buffer kvpn--buffer
      (kvpn--stop-processes))
    (message "Stopping VPN...")))

(provide 'kvpn)

;;; kvpn.el ends here
