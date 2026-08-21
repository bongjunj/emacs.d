;; -*- lexical-binding: t; -*-

(defun my-gptel-find-file (filepath)
  "Visit FILEPATH without displaying it or changing the selected window."
  (let ((path (expand-file-name filepath default-directory)))
    (condition-case err
        (progn
          (unless (file-exists-p path)
            (error "File does not exist: %s. Check if the path is correct."
                   path))

          (let ((buffer (find-file-noselect path)))
            (format "buffer: %s\nfile: %s\nmodified: %s"
                    (buffer-name buffer)
                    (or (buffer-file-name buffer) "")
                    (if (buffer-modified-p buffer) "yes" "no"))))

      (error
       (format "Could not open %s: %s"
               path
               (error-message-string err))))))

(defun my-gptel-read-file (filepath &optional start-line end-line)
  "Return a line range from FILEPATH without visiting it.

START-LINE and END-LINE are 1-based and inclusive.  If START-LINE is
nil, read from the beginning.  If END-LINE is nil, read to the end."
  (let* ((path (expand-file-name filepath default-directory))
         (start (or start-line 1)))
    (cond
     ((or (< start 1)
          (and end-line (< end-line start)))
      "Line numbers must be positive, with END-LINE >= START-LINE.")
     ((not (file-readable-p path))
      (format "File does not exist or is not readable: %s" path))
     (t
      (condition-case err
          (with-temp-buffer
            (insert-file-contents path)
            (goto-char (point-min))
            (forward-line (1- start))
            (let ((beg (point)))
              (if end-line
                  (forward-line (1+ (- end-line start)))
                (goto-char (point-max)))
              (buffer-substring-no-properties beg (point))))
        (error
         (format "Could not read %s: %s"
                 path (error-message-string err))))))))

(defun my-gptel-read-buffer (buffer)
  "Return BUFFER contents."
  (let ((buf (get-buffer buffer)))
    (unless (buffer-live-p buf)
      (error "Buffer does not exist: %s" buffer))
    (with-current-buffer buf
      (save-restriction
        (widen)
        (buffer-substring-no-properties (point-min) (point-max))))))

(defun codel-edit-buffer (buffer-name old-string new-string)
  "In BUFFER-NAME, replace OLD-STRING with NEW-STRING."
  (with-current-buffer buffer-name
    (let ((case-fold-search nil))
      (save-excursion
        (goto-char (point-min))
        (let ((count 0))
          (while (search-forward old-string nil t)
            (setq count (1+ count)))
          (if (= count 0)
              (format "Error: Could not find text to replace in buffer %s" buffer-name)
            (if (> count 1)
                (format "Error: Found %d matches for the text to replace in buffer %s" count buffer-name)
              (goto-char (point-min))
              (search-forward old-string)
              (replace-match new-string t t)
              (format "Successfully edited buffer %s" buffer-name))))))))

(defun codel-replace-buffer (buffer-name content)
  "Completely replace contents of BUFFER-NAME with CONTENT."
  (with-current-buffer buffer-name
    (erase-buffer)
    (insert content)
    (format "Buffer replaced: %s" buffer-name)))

(defun my-gptel-save-buffer (buffer)
  "Save BUFFER."
  (let ((buf (get-buffer buffer)))
    (unless (buffer-live-p buf)
      (error "Buffer does not exist: %s" buffer))
    (with-current-buffer buf
      (unless buffer-file-name
        (error "Buffer is not visiting a file: %s" buffer))
      (save-buffer)
      (format "Saved %s" buffer-file-name))))

(defun my-gptel-list-buffer ()
  "List buffers"
  (mapconcat #'buffer-name (buffer-list) "\n"))

(defun my-gptel-list-windows ()
  (mapconcat
   (lambda (window)
     (format "frame=%s window=%s buffer=%s %dx%d+%d+%d%s"
             (frame-parameter (window-frame window) 'name)
             window
             (buffer-name (window-buffer window))
             (window-pixel-width window)
             (window-pixel-height window)
             (window-pixel-left window)
             (window-pixel-top window)
             (if (eq window (selected-window)) " [selected]" "")))
   (cl-loop for frame in (frame-list)
            append (window-list frame))
   "\n"))

(defun my-gptel-list-frames ()
  (mapconcat
   (lambda (frame)
     (format "frame=%s name=%s terminal=%s %dx%d%s"
             frame
             (or (frame-parameter frame 'name) "")
             (frame-terminal frame)
             (frame-pixel-width frame)
             (frame-pixel-height frame)
             (if (eq frame (selected-frame)) " [selected]" "")))
   (frame-list)
   "\n"))

(defun my-gptel-get-current-context ()
  (with-current-buffer (window-buffer (selected-window))
    (format
     (concat "buffer: %s\n"
             "file: %s\n"
             "major-mode: %s\n"
             "point: %d\n"
             "line: %d\n"
             "column: %d\n"
             "region: %s\n"
             " narrowed: %s\n\n"
             "context:\n%s")
     (buffer-name)
     (or buffer-file-name "")
     major-mode
     (point)
     (line-number-at-pos)
     (current-column)
     (if (use-region-p)
         (format "%d-%d" (region-beginning) (region-end))
       "none")
     (if (buffer-narrowed-p) "yes" "no")
     (buffer-substring-no-properties
      (max (point-min) (- (point) 1000))
      (min (point-max) (+ (point) 1000))))))

(defun my-gptel-apropos (regexp &optional max-results)
  "Return Elisp functions whose names match REGEXP.

REGEXP is an Emacs regular expression.  MAX-RESULTS limits the number of
returned matches; it defaults to 50."
  (let* ((limit (or max-results 50))
         (symbols (sort (apropos-internal regexp #'fboundp)
                        (lambda (a b)
                          (string< (symbol-name a) (symbol-name b)))))
         (truncated (> (length symbols) limit)))
    (when (< limit 1)
      (error "MAX-RESULTS must be positive"))
    (setq symbols (cl-subseq symbols 0 (min limit (length symbols))))
    (if (null symbols)
        "No matching functions."
      (concat
       (when truncated
         (format "Showing the first %d matches.\n\n" limit))
       (mapconcat
        (lambda (symbol)
          (format "%s\n  %s"
                  symbol
                  (replace-regexp-in-string
                   "[ \t\n]+" " "
                   (or (documentation symbol t) "No documentation"))))
        symbols
        "\n")))))

(defun my-gptel-describe-symbol (symbol)
  (let* ((sym (intern symbol))
         (function-doc (when (fboundp sym)
                         (documentation sym t)))
         (variable-doc (when (boundp sym)
                         (documentation-property
                          sym 'variable-documentation t)))
         (value (when (boundp sym)
                  (format "%S" (symbol-value sym)))))
    (unless (or (fboundp sym) (boundp sym))
      (error "Unknown symbol: %s" symbol))
    (format
     "symbol: %s\nfunction: %s\n\nvariable value: %s\nvariable documentation: %s"
     sym
     (or function-doc "Not a function")
     (or value "Not a bound variable")
     (or variable-doc "No variable documentation"))))

(defun my-gptel-magit-git-readonly (directory args)
  "Run a read-only Git command through Magit in DIRECTORY."
  (require 'magit)
  (let ((args (append args nil))
        (allowed-commands
         '("status" "log" "diff" "show" "branch" "rev-parse")))
    (unless (and args (member (car args) allowed-commands))
      (error "Git command not allowed: %s" (car args)))
    (let ((default-directory
           (file-name-as-directory (expand-file-name directory))))
      (mapconcat #'identity
                 (apply #'magit-git-lines args)
                 "\n"))))

(defun my-gptel-project-find-regexp (regexp)
  "Search the current project for REGEXP using Emacs project facilities.

Results are displayed in an xref buffer.  Use `read_buffer` on the
returned buffer to inspect them."
  (require 'project)
  (require 'xref)
  (project-current t)
  (project-find-regexp regexp)
  "Search results are displayed in *xref*.")

(defun my-gptel-project-dired ()
  "Open the current project root in a Dired buffer."
  (require 'project)
  (let* ((project (project-current t))
         (root (project-root project))
         (buffer (dired-noselect root)))
    (format "Project root: %s\nDired buffer: %s"
            root
            (buffer-name buffer))))

(defun my-gptel-project-shell-command (callback command)
  "Run COMMAND asynchronously in the current project's root for gptel.
CALLBACK is supplied first by gptel and invoked with the output string."
  (require 'project)
  (let* ((default-directory
          (file-name-as-directory
           (project-root (project-current t))))
         (buffer (generate-new-buffer " *my-gptel-project-shell-command*"))
         (process (start-file-process-shell-command
                   "my-gptel-project-shell-command"
                   buffer
                   command)))
    (set-process-query-on-exit-flag process nil)
    (set-process-sentinel
     process
     (lambda (proc _event)
       (when (memq (process-status proc) '(exit signal))
         (let ((output
                (when (buffer-live-p (process-buffer proc))
                  (with-current-buffer (process-buffer proc)
                    (buffer-substring-no-properties (point-min) (point-max))))))
           (when (buffer-live-p (process-buffer proc))
             (kill-buffer (process-buffer proc)))
           (when (functionp callback)
             (funcall callback (or output "")))))))
    process))

(defun my-gptel-switch-to-buffer (buffer)
  "Display BUFFER in another window and select that window."
  (let ((buf (get-buffer buffer)))
    (unless (buffer-live-p buf)
      (error "Buffer does not exist: %s" buffer))
    (switch-to-buffer-other-window buf)
    (format "Displayed and selected buffer in another window: %s"
            (buffer-name buf))))

(defun my-gptel-project-magit-status ()
  "Open a Magit status buffer for the current project."
  (require 'project)
  (require 'magit)
  (let* ((root (project-root (project-current t)))
         (buffer (magit-status root)))
    (format "Project root: %s\nMagit buffer: %s"
            root
            (buffer-name buffer))))

(defun my-gptel-project-magit-diff ()
  "Open a Magit diff buffer for the current project."
  (require 'project)
  (require 'magit)
  (let ((default-directory
         (project-root (project-current t))))
    (magit-diff-unstaged)
    (format "Project root: %s\nMagit diff buffer: %s"
            default-directory
            (buffer-name (current-buffer)))))

(defun my-gptel-project-magit-log ()
  "Open a Magit log buffer for the current project."
  (require 'project)
  (require 'magit)
  (let ((default-directory
         (project-root (project-current t))))
    (magit-log-all)
    (format "Project root: %s\nMagit log buffer: %s"
            default-directory
            (buffer-name (current-buffer)))))

(provide 'tools)
