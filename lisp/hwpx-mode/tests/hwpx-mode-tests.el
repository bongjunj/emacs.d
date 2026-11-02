;;; hwpx-mode-tests.el --- HWPX Org integration tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'hwpx-mode)

(defconst hwpx-test--fixture-script
  (expand-file-name "hwpx_bridge_tests.py"
                    (file-name-directory (or load-file-name buffer-file-name))))

(defmacro hwpx-test--with-document (&rest body)
  (declare (indent 0) (debug t))
  `(let* ((directory (make-temp-file "hwpx-tests-" t))
          (source (expand-file-name "회의록.hwpx" directory))
          (output (expand-file-name "수정.hwpx" directory))
          (before (buffer-list)))
     (unwind-protect
         (progn
           (should (eq 0 (call-process hwpx-python-command nil nil nil
                                      hwpx-test--fixture-script "--fixture" source)))
           ,@body)
       (dolist (buffer (cl-set-difference (buffer-list) before))
         (with-current-buffer buffer (set-buffer-modified-p nil))
         (kill-buffer buffer))
       (delete-directory directory t))))

(defun hwpx-test--table ()
  (let ((block (cl-find 'table hwpx--blocks :key (lambda (b) (plist-get b :kind)))))
    (goto-char (1+ (plist-get block :start)))
    block))

(ert-deftest hwpx-org-no-op-save-preserves-every-byte ()
  (hwpx-test--with-document
    (hwpx-open source)
    (should (derived-mode-p 'org-mode))
    (should (eq (key-binding (kbd "RET")) #'org-return))
    (should (eq (key-binding (kbd "C-c `")) #'undefined))
    (should (= (length hwpx--entries) 8))
    (should (= (hash-table-count (hwpx--collect-edits)) 0))
    (hwpx--write output)
    (should (equal hwpx--source-sha256 hwpx--output-sha256))))

(ert-deftest hwpx-org-native-cell-edit-align-save ()
  (hwpx-test--with-document
    (hwpx-open source)
    (hwpx-test--table)
    (org-table-get-field 2 "한글 & <수정>")
    (org-table-align)
    (should (= (hash-table-count (hwpx--collect-edits)) 1))
    (hwpx--write output)
    (let ((entries (alist-get 'entries (hwpx--call (list "inspect" output)))))
      (should (cl-find "한글 & <수정>" entries
                       :key (lambda (e) (alist-get 'text e)) :test #'equal)))
    (should (hwpx-save))))

(ert-deftest hwpx-org-cell-bullets-display-fill-and-preserve-styles ()
  (hwpx-test--with-document
    (should (eq 0 (call-process hwpx-python-command nil nil nil
                               hwpx-test--fixture-script "--bullet-fixture" source)))
    (hwpx-open source)
    (should (string-match-p "^- First bullet" (buffer-string)))
    (should (string-match-p "\n  - Nested bullet" (buffer-string)))
    (should-not (string-match-p "\\*\\* First bullet" (buffer-string)))
    (should (= (hash-table-count (hwpx--collect-edits)) 0))
    (let ((block (car hwpx--blocks)))
      (goto-char (1+ (plist-get block :start)))
      (fill-paragraph)
      (should (= (hash-table-count (hwpx--collect-edits)) 0)))
    (let ((block (car hwpx--blocks)))
      (goto-char (1+ (plist-get block :start)))
      (search-forward "Nested bullet")
      (insert " edited")
      (hwpx--write output)
      (let ((entry (cadr (alist-get 'entries (hwpx--call (list "inspect" output))))))
        (should (equal (alist-get 'text entry) "Nested bullet edited"))
        (should (= (alist-get 'level (alist-get 'list entry)) 1))))))

(ert-deftest hwpx-org-cell-bullets-add-items ()
  (hwpx-test--with-document
    (should (eq 0 (call-process hwpx-python-command nil nil nil
                               hwpx-test--fixture-script "--bullet-fixture" source)))
    (hwpx-open source)
    (goto-char (1- (plist-get (car hwpx--blocks) :end)))
    (insert "\n- new item")
    (hwpx--write output)
    (should (cl-find "new item"
                     (alist-get 'entries (hwpx--call (list "inspect" output)))
                     :key (lambda (entry) (alist-get 'text entry)) :test #'equal))))

(ert-deftest hwpx-org-list-commands-add-delete-indent-and-save ()
  (hwpx-test--with-document
    (should (eq 0 (call-process hwpx-python-command nil nil nil
                               hwpx-test--fixture-script "--bullet-fixture" source)))
    (hwpx-open source)
    (goto-char (point-min))
    (search-forward "Nested bullet")
    (org-metaleft)
    (org-meta-return)
    (insert "Inserted bullet")
    (org-metaright)
    (goto-char (point-min))
    (search-forward "Last bullet")
    (beginning-of-line)
    (delete-region (point) (line-beginning-position 2))
    (hwpx--write output)
    (let ((entries (alist-get 'entries (hwpx--call (list "inspect" output)))))
      (should (equal (mapcar (lambda (e) (alist-get 'level (alist-get 'list e))) entries)
                     '(0 0 1)))
      (should (equal (alist-get 'text (nth 2 entries)) "Inserted bullet"))
      (should (string-suffix-p "  " (alist-get 'text (car entries))))
      (should (cl-every (lambda (e) (= (alist-get 'colspan (alist-get 'cell e)) 2)) entries)))))

(ert-deftest hwpx-org-deleting-all-items-leaves-empty-cell-after-overwrite ()
  (hwpx-test--with-document
    (should (eq 0 (call-process hwpx-python-command nil nil nil
                               hwpx-test--fixture-script "--bullet-fixture" source)))
    (hwpx-open source)
    (let ((block (car hwpx--blocks)))
      (delete-region (1+ (plist-get block :start)) (1- (plist-get block :end))))
    (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
      (hwpx--write source))
    (let ((entries (alist-get 'entries (hwpx--call (list "inspect" source)))))
      (should (= (length entries) 1))
      (should (equal (alist-get 'text (car entries)) ""))
      (should-not (alist-get 'list (car entries)))
      (should (= (alist-get 'colspan (alist-get 'cell (car entries))) 2)))
    (should (= (hash-table-count (hwpx--collect-edits)) 0))
    (should (= (hash-table-count hwpx--list-edits) 0))))

(ert-deftest hwpx-org-list-rejects-unmapped-org-elements ()
  (hwpx-test--with-document
    (should (eq 0 (call-process hwpx-python-command nil nil nil
                               hwpx-test--fixture-script "--bullet-fixture" source)))
    (hwpx-open source)
    (goto-char (1- (plist-get (car hwpx--blocks) :end)))
    (insert "\n#+TITLE: unsupported content\n")
    (should-error (hwpx--write output) :type 'user-error)
    (should-not (file-exists-p output))))

(ert-deftest hwpx-org-list-overwrite-original-and-save-again ()
  (hwpx-test--with-document
    (should (eq 0 (call-process hwpx-python-command nil nil nil
                               hwpx-test--fixture-script "--bullet-fixture" source)))
    (hwpx-open source)
    (goto-char (point-min))
    (search-forward "Nested bullet")
    (org-insert-item)
    (insert "Added item")
    (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
      (hwpx--write source)
      (should (= (hash-table-count (hwpx--collect-edits)) 0))
      (should (= (hash-table-count hwpx--list-edits) 0))
      (goto-char (point-min))
      (search-forward "Added item")
      (insert " updated")
      (hwpx-save))
    (should (cl-find "Added item updated"
                     (alist-get 'entries (hwpx--call (list "inspect" source)))
                     :key (lambda (e) (alist-get 'text e)) :test #'equal))))

(ert-deftest hwpx-org-list-edits-preserve-existing-explicit-line-breaks ()
  (hwpx-test--with-document
    (should (eq 0 (call-process hwpx-python-command nil nil nil
                               hwpx-test--fixture-script "--bullet-break-fixture" source)))
    (hwpx-open source)
    (goto-char (point-min))
    (search-forward "Nested bullet")
    (org-meta-return)
    (insert "Inserted item")
    (hwpx--write output)
    (let ((entries (alist-get 'entries (hwpx--call (list "inspect" output)))))
      (should (cl-find "Last bullet\ncontinued" entries
                       :key (lambda (e) (alist-get 'text e)) :test #'equal)))))

(ert-deftest hwpx-org-empty-cell-and-tab-navigation ()
  (hwpx-test--with-document
    (hwpx-open source)
    (hwpx-test--table)
    (forward-line 1)
    (org-table-goto-column 1)
    (org-table-next-field)
    (should (= (org-table-current-column) 2))
    (org-table-get-field nil "새 참석자")
    (org-table-align)
    (hwpx--write output)
    (should (cl-find "새 참석자"
                     (alist-get 'entries (hwpx--call (list "inspect" output)))
                     :key (lambda (e) (alist-get 'text e)) :test #'equal))))

(ert-deftest hwpx-org-prose-soft-wrap-and-explicit-break ()
  (hwpx-test--with-document
    (hwpx-open source)
    (let ((block (car hwpx--blocks)))
      (goto-char (1- (plist-get block :end)))
      (insert " soft\nwrap\\\\\n다음 줄")
      (should (equal (gethash (alist-get 'id (car hwpx--entries))
                             (hwpx--collect-edits))
                     "Hello world soft wrap\n다음 줄"))
      (hwpx--write output))))

(ert-deftest hwpx-org-rejects-row-and-column-structure-changes ()
  (dolist (kind '(row column))
    (hwpx-test--with-document
      (hwpx-open source)
      (hwpx-test--table)
      (if (eq kind 'row) (org-table-insert-row) (org-table-insert-column))
      (should-error (hwpx--write output) :type 'user-error)
      (should-not (file-exists-p output)))))

(ert-deftest hwpx-org-does-not-overwrite-literal-pipe ()
  (hwpx-test--with-document
    (hwpx-open source)
    (hwpx-test--table)
    (org-table-get-field 2 "a\\vert{}b")
    (org-table-align)
    (should (member "a|b" (hash-table-values (hwpx--collect-edits))))))

(ert-deftest hwpx-find-file-selects-org-editor ()
  (hwpx-test--with-document
    (let ((buffer (find-file-noselect source)))
      (with-current-buffer buffer
        (should (derived-mode-p 'org-mode))
        (should hwpx--source)
        (should-not buffer-file-name)
        (should-not (buffer-modified-p))
        (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
          (should-error (hwpx--write source) :type 'user-error))))))

(ert-deftest hwpx-original-overwrite-decline-preserves-file-and-edits ()
  (hwpx-test--with-document
    (hwpx-open source)
    (hwpx-test--table)
    (org-table-get-field 2 "Pending edit")
    (org-table-align)
    (let ((hash hwpx--source-sha256) asked)
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (prompt) (setq asked prompt) nil)))
        (should-error (hwpx--write source) :type 'user-error))
      (should (string-match-p "original HWPX" asked))
      (should (equal hash (hwpx--file-sha256 source)))
      (should (buffer-modified-p))
      (should (= (hash-table-count (hwpx--collect-edits)) 1))
      (should-not hwpx--output))))

(ert-deftest hwpx-original-overwrite-rebases-table-and-prose-for-repeated-saves ()
  (hwpx-test--with-document
    (hwpx-open source)
    (hwpx-test--table)
    (org-table-get-field 2 "First save")
    (org-table-align)
    (let ((prose (car hwpx--blocks)) (confirmations 0))
      (goto-char (1- (plist-get prose :end)))
      (insert " edited")
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) (cl-incf confirmations) t))
                ((symbol-function 'read-file-name) (lambda (&rest _) source)))
        (hwpx-save-as)
        (should (= (hash-table-count (hwpx--collect-edits)) 0))
        (should (equal hwpx--source-sha256 (hwpx--file-sha256 source)))
        (should (equal (plist-get prose :initial) "Hello world edited"))
        ;; Returning to the text from before the overwrite is a new edit.
        (hwpx-test--table)
        (org-table-get-field 2 "기존값")
        (org-table-align)
        (goto-char (1- (plist-get prose :end)))
        (delete-region (- (point) (length " edited")) (point))
        (should (= (hash-table-count (hwpx--collect-edits)) 2))
        (hwpx-save)
        (should (= confirmations 2)))
      (should (= (hash-table-count (hwpx--collect-edits)) 0))
      (let ((entries (alist-get 'entries (hwpx--call (list "inspect" source)))))
        (should (equal (alist-get 'text (car entries)) "Hello world"))
        (should (cl-find "기존값" entries :key (lambda (e) (alist-get 'text e))
                         :test #'equal))))))

(ert-deftest hwpx-existing-output-prompts-before-first-overwrite ()
  (hwpx-test--with-document
    (hwpx-open source)
    (with-temp-file output (insert "Existing file"))
    (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
      (should-error (hwpx--write output) :type 'user-error))
    (should (equal (with-temp-buffer
                     (insert-file-contents output) (buffer-string)) "Existing file"))
    (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
      (hwpx--write output))
    (cl-letf (((symbol-function 'yes-or-no-p)
               (lambda (&rest _) (ert-fail "Selected output should not prompt again"))))
      (hwpx-save))))

(ert-deftest hwpx-save-buffer-uses-copy-writer ()
  (hwpx-test--with-document
    (hwpx-open source)
    (hwpx-test--table)
    (org-table-get-field 2 "Saved by C-x C-s")
    (org-table-align)
    (cl-letf (((symbol-function 'read-file-name) (lambda (&rest _) output)))
      (save-buffer))
    (should (file-exists-p output))
    (should-not (buffer-modified-p))))

(ert-deftest hwpx-save-refuses-external-changes ()
  (hwpx-test--with-document
    (hwpx-open source)
    (hwpx--write output)
    (with-temp-file output (insert "changed elsewhere"))
    (set-buffer-modified-p t)
    (should-error (hwpx-save) :type 'user-error)
    (should (buffer-modified-p))))
