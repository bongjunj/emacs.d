;;; bongjun-embark-expreg.el --- Expreg targets for Embark -*- lexical-binding: t; -*-

;;; Commentary:
;; Add Expreg's region sizes to Embark's target cycle in Lisp buffers and
;; buffers with an active Tree-sitter parser.  Keep semantic targets and
;; minibuffer behavior.

;;; Code:

(require 'cl-lib)
(require 'embark)
(require 'expreg)
(require 'seq)
(require 'treesit)

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

(defun bongjun/embark-expreg-setup ()
  "Insert Expreg targets before Embark's generic expression targets.
Preserve other target finders and avoid duplicates when reevaluated."
  (let* ((finders (remq #'bongjun/embark-target-expreg embark-target-finders))
         (index (or (cl-position #'embark-target-expression-at-point finders)
                    (length finders))))
    (setq embark-target-finders
          (append (seq-take finders index)
                  '(bongjun/embark-target-expreg)
                  (seq-drop finders index)))))

(provide 'bongjun-embark-expreg)
;;; bongjun-embark-expreg.el ends here
