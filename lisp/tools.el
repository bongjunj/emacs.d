(defun my-gptel-find-file (filepath)
  "Open FILEPATH in an Emacs buffer and return buffer information."
  (let ((buffer (find-file-other-window (expand-file-name filepath))))
    (format "buffer: %s\nfile: %s\nmodified: %s"
            (buffer-name buffer)
            (or (buffer-file-name buffer) "")
            (if (buffer-modified-p buffer) "yes" "no"))))

(defun my-gptel-read-buffer (buffer)
  "Return BUFFER contents with 1-based line numbers.

The displayed line-number prefixes are metadata and are not part of
the buffer contents."
  (let ((buf (get-buffer buffer)))
    (unless (buffer-live-p buf)
      (error "Buffer does not exist: %s" buffer))
    (with-current-buffer buf
      (save-restriction
        (widen)
        (save-excursion
          (goto-char (point-min))
          (let ((line-number 1)
                lines)
            (while (not (eobp))
              (let ((line-start (point)))
                (forward-line 1)
                (push (format "%6d\t%s"
                              line-number
                              (buffer-substring-no-properties
                               line-start (point)))
                      lines))
              (setq line-number (1+ line-number)))
            (apply #'concat (nreverse lines))))))))

(defun my-gptel-replace-buffer-lines
    (buffer start-line end-line text)
  "Replace lines START-LINE through END-LINE in BUFFER with TEXT.

Line numbers are 1-based. END-LINE is exclusive."
  (let ((buf (get-buffer buffer)))
    (unless (buffer-live-p buf)
      (error "Buffer does not exist: %s" buffer))
    (with-current-buffer buf
      (save-restriction
        (widen)
        (goto-char (point-min))
        (forward-line (1- start-line))
        (let ((beg (point)))
          (goto-char (point-min))
          (forward-line (1- end-line))
          (delete-region beg (point))
          (goto-char beg)
          (insert text)))
      (format "Edited buffer %s; modified: %s"
              (buffer-name)
              (if (buffer-modified-p) "yes" "no")))))
(defun my-gptel-insert-at-point (buffer text)
  "Insert TEXT at point in BUFFER."
  (let ((buf (get-buffer buffer)))
    (unless (buffer-live-p buf)
      (error "Buffer does not exist: %s" buffer))
    (with-current-buffer buf
      (insert text)
      (format "Inserted text into %s; modified: yes"
              (buffer-name)))))

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

(defun my-gptel-project-async-shell-command (command)
  "Run COMMAND asynchronously in the current project's root directory."
  (require 'project)
  (let ((default-directory
         (file-name-as-directory
          (project-root (project-current t)))))
    (async-shell-command command)
    (format "Started command in %s\nOutput buffer: %s"
            default-directory
            "*Async Shell Command*")))

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
