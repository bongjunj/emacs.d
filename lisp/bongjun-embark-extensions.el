;;; bongjun-embark-extensions.el --- Extra targets and display rules for Embark -*- lexical-binding: t; -*-

;;; Commentary:
;; Add Expreg's region sizes to Embark's target cycle in Lisp buffers and
;; buffers with an active Tree-sitter parser.  Keep semantic targets and
;; minibuffer behavior.  Add a Git commit target with a Magit action, and
;; hide the mode line in Embark's live and completions collection windows.

;;; Code:

(require 'cl-lib)
(require 'embark)
(require 'expreg)
(require 'seq)
(require 'treesit)
(require 'magit)

(defun bongjun/embark-target-expreg ()
  "Return Expreg regions as Embark targets in Lisp or Tree-sitter buffers.
Targets are ordered from smallest to largest.  If a region is already
active, return only regions that strictly contain it.  Leave point,
mark and Expreg's expansion history untouched."
  (when (and (not (minibufferp))
             (or (derived-mode-p 'lisp-data-mode 'scheme-mode)
                 (and (treesit-available-p)
                      (treesit-parser-list))))
    (save-mark-and-excursion
      (let* ((origin (point))
             (selection (when (use-region-p)
                          (cons (region-beginning) (region-end))))
             ;; Expreg has no public region-list API.  Use the same producers,
             ;; validation and ordering as `expreg-expand', without selecting
             ;; regions or modifying its buffer-local expansion history.
             (regions (mapcan (lambda (function)
                                (save-excursion (funcall function)))
                              expreg-functions))
             (regions (expreg--sort-regions
                       (expreg--filter-regions regions origin)))
             seen targets)
        (dolist (region regions (nreverse targets))
          (let* ((start (cadr region))
                 (end (cddr region))
                 (bounds (cons start end)))
            (when (and (not (member bounds seen))
                       (or (null selection)
                           (and (<= start (car selection))
                                (<= (cdr selection) end)
                                (not (equal bounds selection)))))
              (push bounds seen)
              (push `(region ,(buffer-substring start end) ,start . ,end)
                    targets))))))))

(defun bongjun/embark-target-git-commit ()
  "Target a Git commit hash of 7 to 40 hexadecimal digits at point."
  (unless (minibufferp)
    (when-let* ((bounds (bounds-of-thing-at-point 'symbol))
                (hash (buffer-substring-no-properties
                       (car bounds) (cdr bounds))))
      (when (string-match-p "\\`[[:xdigit:]]\\{7,40\\}\\'" hash)
        `(git-commit ,hash ,(car bounds) . ,(cdr bounds))))))

(defun bongjun/embark-magit-show-commit (commit)
  "Show COMMIT in Magit using the current buffer's repository."
  (interactive "sCommit: ")
  (unless (magit-toplevel)
    (user-error "This buffer's default-directory is not in a Git repository"))
  (magit-show-commit commit))

(defvar bongjun/embark-git-commit-map
  (make-sparse-keymap)
  "Embark actions for Git commit hashes.")

;; Insert Expreg before the generic expression finder without duplicating it.
(let* ((finders (remq #'bongjun/embark-target-expreg embark-target-finders))
       (index (or (cl-position #'embark-target-expression-at-point finders)
                  (length finders))))
  (setq embark-target-finders
        (append (seq-take finders index)
                '(bongjun/embark-target-expreg)
                (seq-drop finders index))))

(set-keymap-parent bongjun/embark-git-commit-map embark-general-map)
(define-key bongjun/embark-git-commit-map (kbd "g")
            #'bongjun/embark-magit-show-commit)
(add-to-list 'embark-keymap-alist
             '(git-commit . bongjun/embark-git-commit-map))
(add-to-list 'embark-target-finders #'bongjun/embark-target-git-commit)

;; Hide the mode line in Embark's live and completions collection windows.
(add-to-list 'display-buffer-alist
             '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
               nil
               (window-parameters (mode-line-format . none))))

(provide 'bongjun-embark-extensions)
;;; bongjun-embark-extensions.el ends here
