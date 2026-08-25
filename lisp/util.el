;; -*- lexical-binding: t; -*-

(defun kvpn-start ()
    "Start KVPN and handle SMS and sudo password prompts."
    (interactive)
    (when-let ((old (get-process "kvpn-process")))
      (delete-process old))
    (let ((proc
           (make-process
            :name "kvpn-process"
            :buffer "*KVPN Log*"
            :command '("kvpn")
            ;; Required so sudo can read the Mac password interactively.
            :connection-type 'pty
            :noquery t
            :filter
            (lambda (proc output)
              (with-current-buffer (process-buffer proc)
                (goto-char (point-max))
                (insert output))
              (let ((text (downcase output)))
                (cond
                 ;; Choose the default delivery method: SMS.
                 ((string-match-p "choice \\[1\\]:" text)
                  (process-send-string proc "\n"))

                 ;; Enter the verification code received by SMS.
                 ((string-match-p "enter the code:" text)
                  (process-send-string
                   proc
                   (concat (read-string "KAIST VPN SMS code: ") "\n")))

                 ;; Enter the local Mac account password for sudo.
                 ((string-match-p
                   "\\(\\[sudo\\] password\\|password:\\)" text)
                  (process-send-string
                   proc
                   (concat (read-passwd "Mac password for sudo: ") "\n"))))))
            :sentinel
            (lambda (_proc event)
              (message "KVPN process state: %s" (string-trim event))))))
      (pop-to-buffer "*KVPN Log*")
      proc))

(defun kvpn-stop ()
  "Stop the running VPN process."
  (interactive)
  (when-let ((proc (get-process "kvpn-process")))
    (delete-process proc)
    (message "VPN disconnected.")))

(provide 'util)
