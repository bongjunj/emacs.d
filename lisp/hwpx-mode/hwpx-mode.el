;;; hwpx-mode.el --- Edit existing HWPX text with Org -*- lexical-binding: t; -*-

;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org "9.6"))
;; Keywords: files, wp

;;; Commentary:
;; Project existing HWPX text into Org tables and prose.  Save edited text to
;; a file while retaining the source package's document structure and styles.
;; The adjacent hwpx_bridge.py uses only the Python 3.9+ standard library.

;;; Code:
(require 'cl-lib)
(require 'json)
(require 'org)
(require 'org-element)
(require 'org-table)

(defgroup hwpx nil "Edit HWPX documents with Org." :group 'files)
(defcustom hwpx-python-command "python3"
  "Python 3 executable used for HWPX packages." :type 'string)
(defcustom hwpx-long-cell-width 72
  "Cells wider than this become Org body text." :type 'integer)
(defconst hwpx--bridge
  (expand-file-name "hwpx_bridge.py"
                    (file-name-directory (or load-file-name buffer-file-name))))
(defvar-local hwpx--source nil)
(defvar-local hwpx--source-sha256 nil)
(defvar-local hwpx--output nil)
(defvar-local hwpx--output-sha256 nil)
(defvar-local hwpx--entries nil)
(defvar-local hwpx--edits nil)
(defvar-local hwpx--list-edits nil)
(defvar-local hwpx--blocks nil)
(defvar-local hwpx--template nil)

(defun hwpx--call (arguments &optional request)
  "Run the bridge with ARGUMENTS and optional JSON REQUEST."
  (let ((output (generate-new-buffer " *hwpx-result*"))
        (errors (make-temp-file "hwpx-errors-"))
        (coding-system-for-read 'utf-8-unix)
        (coding-system-for-write 'utf-8-unix))
    (unwind-protect
        (with-temp-buffer
          (when request (insert (json-serialize request)))
          (let ((status (apply #'call-process-region
                               (point-min) (point-max) hwpx-python-command
                               nil (list output errors) nil hwpx--bridge arguments)))
            (unless (eq status 0)
              (user-error "HWPX: %s"
                          (with-temp-buffer
                            (insert-file-contents errors)
                            (string-trim (buffer-string)))))
            (with-current-buffer output
              (goto-char (point-min))
              (json-parse-buffer :object-type 'alist :array-type 'list
                                 :false-object nil :null-object nil))))
      (kill-buffer output)
      (delete-file errors))))

(defun hwpx--protected (text)
  "Insert structural TEXT without allowing accidental deletion."
  (insert (propertize text 'read-only t 'rear-nonsticky t)))

(defun hwpx--encode-field (text)
  "Encode literal TEXT for an Org table field."
  (replace-regexp-in-string "|" "\\vert{}" (string-trim text) t t))

(defun hwpx--paragraph (entry &optional heading)
  "Insert ENTRY as editable Org text, optionally as a HEADING."
  (let* ((list-info (alist-get 'list entry))
         (level (or (alist-get 'level list-info) 0))
         (indent (when list-info (make-string (+ 2 (* 2 level)) ?\s))))
    (when list-info
      (setq heading nil)
      (hwpx--protected (concat (make-string (* 2 level) ?\s) "- ")))
    (when heading (hwpx--protected "** "))
    (when (= (point) (point-min)) (hwpx--protected "\n"))
    (let* ((original (alist-get 'text entry))
           (text (if heading (string-trim original)
                   (replace-regexp-in-string "\n" "\\\\\n" original t t)))
           (start (copy-marker (1- (point)))))
      (when indent
	(setq text (replace-regexp-in-string "\n" (concat "\n" indent) text t t)))
      (insert text)
      (unless (alist-get 'editable entry)
	(add-text-properties (1+ start) (point) '(read-only t rear-nonsticky t)))
      (hwpx--protected "\n")
      (push (list :kind (if heading 'heading 'paragraph)
                  :start start :end (copy-marker (point))
                  :entry entry :initial text :continuation-indent indent) hwpx--blocks))
    (hwpx--protected "\n")))

(defun hwpx--cell-body (cell)
  "Show a multi-paragraph CELL with an Org heading."
  (let ((entries (alist-get 'entries cell)))
    (if (and (> (length entries) 1)
             (not (alist-get 'list (car entries)))
             (< (string-width (alist-get 'text (car entries))) 32))
        (progn (hwpx--paragraph (car entries) t)
               (hwpx--cell-entries (cdr entries)))
      (hwpx--cell-entries entries))))

(defun hwpx--cell-entries (entries)
  "Render contiguous bullet ENTRIES as editable Org lists."
  (while entries
    (if (not (alist-get 'list (car entries)))
        (hwpx--paragraph (pop entries))
      (let (group)
        (while (and entries (alist-get 'list (car entries)))
          (push (pop entries) group))
        (hwpx--list (nreverse group))))))

(defun hwpx--list (entries)
  "Insert ENTRIES as an editable Org list inside its existing cell."
  (when (= (point) (point-min)) (hwpx--protected "\n"))
  (let ((start (copy-marker (1- (point)))))
    (cl-loop for entry in entries for first = t then nil do
             (unless first (insert "\n"))
             (let* ((level (alist-get 'level (alist-get 'list entry)))
                    (indent (make-string (+ 2 (* 2 level)) ?\s))
                    (text (replace-regexp-in-string
                           "\n" (concat "\\\\\n" indent)
                           (alist-get 'text entry) t t)))
               (insert (make-string (* 2 level) ?\s) "- " text)))
    ;; The last item's newline is editable, so normal line deletion works.
    (insert "\n")
    (unless (cl-every (lambda (entry) (alist-get 'editable entry)) entries)
      (add-text-properties (1+ start) (point) '(read-only t rear-nonsticky t)))
    (let ((initial (buffer-substring-no-properties (1+ start) (point))))
      (hwpx--protected "\n")
      (push (list :kind 'list :start start :end (copy-marker (point))
                  :entries entries :initial initial) hwpx--blocks))
    (hwpx--protected "\n")))

(defun hwpx--table (rows)
  "Insert ROWS as a native Org table, retaining its cell mapping."
  (when rows
    (when (= (point) (point-min)) (hwpx--protected "\n"))
    (let ((start (copy-marker (1- (point)))) mapping)
      (dolist (row rows)
        (push (mapcar (lambda (c) (car (alist-get 'entries c))) row) mapping)
        (insert "| " (mapconcat
                       (lambda (c) (hwpx--encode-field
                                    (alist-get 'text (car (alist-get 'entries c)))))
                       row " | ") " |\n"))
      (let ((end (copy-marker (point) t)))
        (save-excursion (goto-char (1+ start)) (org-table-align))
        (goto-char end)
        (set-marker end nil)
        (hwpx--protected "\n")
        (push (list :kind 'table :start start :end (copy-marker (point))
                    :rows (nreverse mapping)) hwpx--blocks)))))

(defun hwpx--long-cell-p (cell)
  "Whether CELL is better displayed as ordinary Org prose."
  (let ((entries (alist-get 'entries cell)))
    (or (/= (length entries) 1)
        (alist-get 'list (car entries))
        (string-match-p "\n" (alist-get 'text (car entries)))
        (> (string-width (alist-get 'text (car entries))) hwpx-long-cell-width))))

(defun hwpx--render-table (entries)
  "Render ENTRIES from an HWPX table using native Org tables and prose."
  (let (cells rows group signature)
    (dolist (entry entries)
      (let* ((meta (alist-get 'cell entry))
             (id (alist-get 'id meta))
             (cell (cl-find id cells :key (lambda (c) (alist-get 'id c))
                            :test #'equal)))
        (if cell
            (setf (alist-get 'entries cell)
                  (append (alist-get 'entries cell) (list entry)))
          (setq cells (append cells (list (append meta `((entries . (,entry))))))))))
    (dolist (cell cells)
      (let* ((row-no (alist-get 'row cell)) (row (assoc row-no rows)))
        (if row (setcdr row (append (cdr row) (list cell)))
          (setq rows (append rows (list (list row-no cell)))))))
    (dolist (row rows)
      (let* ((row-cells (cdr row))
             (vertical (cl-remove-if-not
                        (lambda (c) (> (alist-get 'rowspan c) 1)) row-cells)))
        (when vertical
          (hwpx--table group)
          (setq group nil signature nil)
          (dolist (cell vertical) (hwpx--cell-body cell))
          (setq row-cells (cl-set-difference row-cells vertical)))
        (cond
         ((null row-cells))
         ((cl-some #'hwpx--long-cell-p row-cells)
          (hwpx--table group)
          (setq group nil signature nil)
          (if (and (= (length row-cells) 2)
                   (not (hwpx--long-cell-p (car row-cells))))
              (progn
                (hwpx--paragraph (car (alist-get 'entries (car row-cells))) t)
                (hwpx--cell-entries (alist-get 'entries (cadr row-cells))))
            (dolist (cell row-cells) (hwpx--cell-body cell))))
         (t
          (let ((shape (mapcar (lambda (c) (list (alist-get 'column c)
                                                (alist-get 'colspan c))) row-cells)))
            (unless (equal signature shape)
              (hwpx--table group)
              (setq group nil signature shape))
            (setq group (append group (list row-cells))))))))
    (hwpx--table group)))

(defun hwpx--render ()
  "Create the Org editing projection of the original document."
  (let ((inhibit-read-only t) (entries hwpx--entries))
    (erase-buffer)
    (setq hwpx--blocks nil)
    (while entries
      (let ((table (alist-get 'table (alist-get 'cell (car entries)))))
        (if (not table)
            (hwpx--paragraph (pop entries))
          (let (group)
            (while (and entries
                        (equal table (alist-get 'table (alist-get 'cell (car entries)))))
              (push (pop entries) group))
            (hwpx--render-table (nreverse group))))))
    (setq hwpx--blocks (nreverse hwpx--blocks))
    (setq hwpx--template (hwpx--skeleton))
    (goto-char (point-min))
    (set-buffer-modified-p nil)
    (setq buffer-undo-list nil)))

(defun hwpx--skeleton ()
  "Return the structural text outside all mapped editable fields."
  (let ((previous (point-min)) parts)
    (dolist (block hwpx--blocks)
      (let ((start (1+ (plist-get block :start)))
            (end (1- (plist-get block :end))))
        (unless (<= previous start end)
          (user-error "편집 영역의 경계가 바뀌었습니다. 실행 취소 후 다시 저장하세요"))
        (push (buffer-substring-no-properties previous start) parts)
        (setq previous end)))
    (nreverse (cons (buffer-substring-no-properties previous (point-max)) parts))))

(defun hwpx--decode-prose (text &optional continuation-indent)
  "Interpret Org soft newlines as spaces and explicit line breaks as newlines."
  (when continuation-indent
    (setq text (replace-regexp-in-string
                (concat "\n" (regexp-quote continuation-indent)) "\n" text t t)))
  (setq text (replace-regexp-in-string (regexp-quote "\\\\\n") "\r" text t t))
  (setq text (replace-regexp-in-string "\n" " " text t t))
  (replace-regexp-in-string "\r" "\n" text t t))

(defun hwpx--parse-list ()
  "Return Org list items as HWPX text and levels in the narrowed buffer."
  (if (string-empty-p (string-trim (buffer-string)))
      []
    (goto-char (point-min))
    (unless (looking-at "[ \t]*[-+*] ")
      (user-error "Use an Org bullet list in this cell"))
    (let ((tree (org-element-parse-buffer)) items)
      (dolist (section (org-element-contents tree))
        (unless (eq (org-element-type section) 'section)
          (user-error "Keep text inside bullet items"))
        (dolist (element (org-element-contents section))
          (unless (eq (org-element-type element) 'plain-list)
            (user-error "Only Org bullet lists are supported in this cell"))))
      (org-element-map tree 'paragraph
        (lambda (p)
          (unless (org-element-lineage p '(item))
            (user-error "Keep text inside bullet items"))))
      (org-element-map tree 'item
        (lambda (item)
          (let* ((parts (cl-remove-if-not
                         (lambda (part) (eq (org-element-type part) 'paragraph))
                         (org-element-contents item)))
                 (indent (save-excursion
                           (goto-char (org-element-property :begin item))
                           (current-indentation)))
                 (level (/ indent 2))
                 (body (if parts
                           (string-trim-right
                            (buffer-substring-no-properties
                             (org-element-property :begin (car parts))
                             (org-element-property :end (car parts))))
                         "")))
            (dolist (part (org-element-contents item))
              (unless (memq (org-element-type part) '(paragraph plain-list))
                (user-error "Only text and nested bullets are supported in a list")))
            (when (or (> (length parts) 1) (> level 9) (/= (% indent 2) 0))
              (user-error "Each bullet must be a single paragraph with two-space nesting"))
            (push `((text . ,(hwpx--decode-prose body (make-string (+ indent 2) ?\s)))
                    (level . ,level)) items))))
      (unless items (user-error "No Org list items found"))
      (vconcat (nreverse items)))))

(defun hwpx--restore-list-text (items entries initial)
  "Preserve original ENTRIES text for unchanged ITEMS rendered as INITIAL."
  (let* ((baseline (with-temp-buffer
                     (let ((org-inhibit-startup t))
                       (delay-mode-hooks (org-mode)))
                     (insert initial)
                     (hwpx--parse-list)))
         (remaining (cl-mapcar (lambda (item entry) (cons (alist-get 'text item) entry))
                               (append baseline nil) entries)))
    (cl-loop for item across items do
             (let ((matched (cl-find (alist-get 'text item) remaining
                                     :key #'car :test #'equal)))
               (when matched
                 (setf (alist-get 'text item) (alist-get 'text (cdr matched)))
                 (setq remaining (delq matched remaining)))))
    items))

(defun hwpx--collect-edits ()
  "Validate the Org projection and collect text changes only."
  (unless (equal hwpx--template (hwpx--skeleton))
    (user-error "원본 양식 보존을 위해 기존 셀·본문 영역 안에서 편집하세요"))
  (let ((edits (make-hash-table :test #'equal)))
    (setq hwpx--list-edits (make-hash-table :test #'equal))
    (cl-labels
        ((record (entry value)
           (unless (equal value (alist-get 'text entry))
             (unless (alist-get 'editable entry)
               (user-error "읽기 전용 문단은 수정할 수 없습니다: %s"
                           (alist-get 'location entry)))
             (when (string-match-p "[\t\r]" value)
               (user-error "셀 안에서는 탭 대신 공백을 사용하세요"))
             (puthash (alist-get 'id entry) value edits))))
      (dolist (block hwpx--blocks)
        (save-restriction
          ;; Anchors live in protected delimiters, outside Org's table rewrites.
          (narrow-to-region (1+ (plist-get block :start))
                            (1- (plist-get block :end)))
          (cond
           ((eq (plist-get block :kind) 'list)
            (unless (equal (buffer-substring-no-properties (point-min) (point-max))
                           (plist-get block :initial))
              (let* ((entries (plist-get block :entries))
                     (items (hwpx--restore-list-text
                             (hwpx--parse-list) entries (plist-get block :initial)))
                     (original (vconcat
                                (mapcar (lambda (entry)
                                          `((text . ,(alist-get 'text entry))
                                            (level . ,(alist-get 'level (alist-get 'list entry)))))
                                        entries))))
                (unless (equal items original)
                  (puthash (alist-get 'id (car entries))
                           `((ids . ,(vconcat (mapcar (lambda (e) (alist-get 'id e)) entries)))
                             (items . ,items)) hwpx--list-edits)))))
           ((eq (plist-get block :kind) 'table)
              (save-excursion
                (goto-char (point-min))
                (unless (org-at-table-p) (user-error "원래 Org 표가 삭제되었습니다"))
                (let* ((rows (cl-remove 'hline (org-table-to-lisp)))
                       (mapping (plist-get block :rows)))
                  (unless (and (= (length rows) (length mapping))
                               (cl-every #'identity
                                         (cl-mapcar (lambda (r m) (= (length r) (length m)))
                                                    rows mapping))
                               (string-empty-p
                                (string-trim
                                 (buffer-substring-no-properties
                                  (org-table-end) (point-max)))))
                    (user-error "원본 양식 보존을 위해 표의 행·열 수를 유지하세요"))
                  (cl-mapc
                   (lambda (row targets)
                     (cl-mapc
                      (lambda (value entry)
                        (unless (equal value (hwpx--encode-field (alist-get 'text entry)))
                          (record entry (replace-regexp-in-string
                                         (regexp-quote "\\vert{}") "|" value t t))))
                      row targets)) rows mapping))))
           (t
            (let* ((entry (plist-get block :entry))
                   (value (buffer-substring-no-properties (point-min) (point-max))))
              (unless (equal value (plist-get block :initial))
                (when (and (alist-get 'list entry)
                           (string-match-p
                            "\n[ \t]*\\(?:[-+*]\\|[0-9]+[.)]\\)[ \t]+" value))
                  (user-error "원본 양식 보존을 위해 기존 목록 항목의 내용만 수정하세요"))
                (when (and (eq (plist-get block :kind) 'heading)
                           (string-match-p "\n" value))
                  (user-error "항목 이름은 한 줄로 유지하세요"))
                (record entry (hwpx--decode-prose
                               value (plist-get block :continuation-indent))))))))))
    edits))

(defvar hwpx-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map org-mode-map)
    (define-key map (kbd "C-x C-s") #'hwpx-save)
    (define-key map (kbd "C-x C-w") #'hwpx-save-as)
    map))

;; Also migrate a map retained by an Emacs running the previous list editor.
(set-keymap-parent hwpx-mode-map org-mode-map)
(keymap-unset hwpx-mode-map "RET" t)
(keymap-set hwpx-mode-map "C-c `" #'undefined)

(define-derived-mode hwpx-mode org-mode "HWPX Org"
  "Edit existing HWPX text using Org tables and prose.
Edit table fields directly; TAB and S-TAB move between fields.
C-x C-s saves with the original XML structures and styles.
Overwriting the original file requires confirmation."
  (setq-local header-line-format
              " Org: TAB/S-TAB 셀 이동 · C-c C-c 표 정렬 · C-x C-s 저장")
  (setq-local org-startup-folded 'showeverything)
  (visual-line-mode 1))

;;;###autoload
(defun hwpx-open (file)
  "Open FILE as an Org editing projection of its existing text."
  (interactive "fHWPX 파일: ")
  (setq file (expand-file-name file))
  (when (file-remote-p file) (user-error "로컬 HWPX 파일을 선택하세요"))
  (let* ((data (hwpx--call (list "inspect" file)))
         (buffer (generate-new-buffer
                  (format "*HWPX: %s*" (file-name-nondirectory file)))))
    (with-current-buffer buffer
      (hwpx-mode)
      (setq hwpx--source file
            hwpx--source-sha256 (alist-get 'source_sha256 data)
            hwpx--entries (alist-get 'entries data)
            hwpx--edits (make-hash-table :test #'equal)
            default-directory (file-name-directory file))
      (setq-local buffer-offer-save t)
      (add-hook 'write-contents-functions #'hwpx-save nil t)
      (hwpx--render))
    (pop-to-buffer buffer)))

(defun hwpx--file-sha256 (file)
  "Return the SHA-256 of FILE's literal bytes."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (secure-hash 'sha256 (current-buffer))))

(defun hwpx--rebase (edits hash)
  "Accept EDITS and HASH as the new baseline after overwriting the source."
  (dolist (entry hwpx--entries)
    (setf (alist-get 'text entry)
          (gethash (alist-get 'id entry) edits (alist-get 'text entry))))
  (dolist (block hwpx--blocks)
    (unless (eq (plist-get block :kind) 'table)
      (setf (plist-get block :initial)
            (buffer-substring-no-properties
             (1+ (plist-get block :start)) (1- (plist-get block :end))))))
  (setq hwpx--source-sha256 hash
        hwpx--edits (make-hash-table :test #'equal)))

(defun hwpx--write (output)
  "Save changed text to OUTPUT, retaining the original layout structures."
  (when-let* ((editor (get-buffer "*Org Table Edit Field*"))
              (marker (buffer-local-value 'org-field-marker editor)))
    (when (and (markerp marker) (eq (marker-buffer marker) (current-buffer)))
      (user-error "Org 셀 편집 버퍼에서 C-c C-c로 먼저 반영하세요")))
  (setq output (expand-file-name output))
  (when (file-remote-p output) (user-error "로컬 저장 경로를 선택하세요"))
  (let* ((original (equal (file-truename output) (file-truename hwpx--source)))
         (same-output (and hwpx--output
                           (equal (file-truename output) (file-truename hwpx--output))))
         (edits (hwpx--collect-edits))
         (exists (file-exists-p output))
         (expected (cond (original hwpx--source-sha256)
                         (same-output hwpx--output-sha256)
                         (exists (hwpx--file-sha256 output))
                         (t :null))))
    (when (and exists (or original (not same-output)))
      (unless (yes-or-no-p
               (if original
                   (format "Overwrite the original HWPX file %s? " output)
                 (format "File %s exists. Overwrite it? " output)))
        (user-error "Save cancelled")))
    (let* ((request `((source_sha256 . ,hwpx--source-sha256)
                     (output_sha256 . ,expected)
                     (overwrite_original . ,(if original t :false))
                    (edits . ,edits)
                    (list_edits . ,hwpx--list-edits)))
           (result (hwpx--call (list "save" hwpx--source output) request)))
      (setq hwpx--edits edits hwpx--output output
            hwpx--output-sha256 (alist-get 'output_sha256 result))
      (when (alist-get 'source_overwritten result)
        (if (> (hash-table-count hwpx--list-edits) 0)
            (let ((position (point))
                  (data (hwpx--call (list "inspect" hwpx--source))))
              (setq hwpx--source-sha256 (alist-get 'source_sha256 data)
                    hwpx--entries (alist-get 'entries data)
                    hwpx--edits (make-hash-table :test #'equal))
              (hwpx--render)
              (goto-char (min position (point-max))))
          (hwpx--rebase edits hwpx--output-sha256)))
      (set-buffer-modified-p nil)
      (message "HWPX 저장 완료: %s" output)
      t)))

(defun hwpx-save ()
  "Save the selected output, prompting for its filename on the first save."
  (interactive)
  (if hwpx--output (hwpx--write hwpx--output) (hwpx-save-as)))

(defun hwpx-save-as ()
  "Choose an output filename, confirming before overwriting an existing file."
  (interactive)
  (hwpx--write
   (read-file-name "HWPX 저장: " (file-name-directory hwpx--source)
                   nil nil (concat (file-name-base hwpx--source) "-edited.hwpx"))))

;;;###autoload
(defun hwpx-find-file ()
  "Open the visited package with the HWPX Org editor."
  (let ((file buffer-file-name) (raw-buffer (current-buffer)))
    (hwpx-open file)
    (with-current-buffer raw-buffer (set-buffer-modified-p nil))
    (kill-buffer raw-buffer)))

(add-to-list 'auto-mode-alist '("\\.hwpx\\'" . hwpx-find-file))
(provide 'hwpx-mode)
;;; hwpx-mode.el ends here
