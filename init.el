(require 'cl-lib)
(setq custom-file "~/.emacs.d/custom.el")
(load custom-file nil nil)

(load-theme 'leuven)

(setq inhibit-startup-screen t)
(tool-bar-mode 0)
(scroll-bar-mode 0)
(menu-bar-mode t)
(global-display-line-numbers-mode 1)
(global-visual-line-mode -1)
(toggle-truncate-lines)
(blink-cursor-mode -1)
(pixel-scroll-precision-mode 1)
(winner-mode 1)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)

;; TRAMP Optimization: https://coredumped.dev/2025/06/18/making-tramp-go-brrrr./
(setq remote-file-name-inhibit-locks t
      tramp-use-scp-direct-remote-copying t
      remote-file-name-inhibit-auto-save-visited t)

(setq tramp-copy-size-limit (* 1024 1024) ;; 1MB
      tramp-verbose 2)

(connection-local-set-profile-variables
 'remote-direct-async-process
 '((tramp-direct-async-process . t)))

(connection-local-set-profiles
 '(:application tramp :protocol "scp")
 'remote-direct-async-process)

(with-eval-after-load 'tramp
  (with-eval-after-load 'compile
    (remove-hook 'compilation-mode-hook #'tramp-compile-disable-ssh-controlmaster-options)))

;; visual indicator at the column of width 80
(setopt display-fill-column-indicator-column 80)
(add-hook 'prog-mode-hook
          (lambda () (display-fill-column-indicator-mode 1)))
(add-hook 'org-mode-hook
          (lambda () (display-fill-column-indicator-mode 1)))
(add-hook 'markdown-mode-hook
          (lambda () (display-fill-column-indicator-mode 1)))


(defalias 'list-buffers 'ibuffer)
(setq ibuffer-saved-filter-groups
      '(("default"
	 ("Dired" (mode . dired-mode))
	 ("Org" (mode . org-mode))
	 ("magit" (name . "^magit")))))
(add-hook 'ibuffer-mode-hook
	  (lambda ()
	    (ibuffer-switch-to-saved-filter-groups "default")))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(add-to-list 'package-selected-packages 'dash)
(add-to-list 'package-selected-packages 'lsp-mode)
(add-to-list 'package-selected-packages 'magit-section)

(setq show-trailing-whitespace t)

(set-face-attribute 'default nil
                    :family "Menlo"
                    :height 140
                    :weight 'regular
                    :slant 'normal)
(use-package which-key
  :ensure nil ;; built-in
  :config
  (which-key-mode))

(use-package exec-path-from-shell
  :ensure t
  :init
  (when (memq window-system '(mac ns x pgtk))
    (exec-path-from-shell-initialize)))


(use-package tramp
  :ensure t
  :config
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path))

;; TODO: resetup with text/synctex
(use-package tex
  :ensure auctex
  :config
  ;; Parse file on load/save for macro completion
  (setq TeX-auto-save t)
  (setq TeX-parse-self t)
  ;; Default to PDF output instead of DVI
  (setq-default TeX-PDF-mode t)

  ;; --- 2. SyncTeX Configuration ---
  ;; Enable SyncTeX for cross-navigation between .tex and .pdf
  (setq TeX-source-correlate-mode t)
  (setq TeX-source-correlate-method 'synctex)
  (setq TeX-source-correlate-start-server t)

  ;; Set PDF Tools as the default viewer for AUCTeX
  (setq TeX-view-program-selection '((output-pdf "PDF Tools")))

  ;; Auto-refresh the PDF buffer after compilation finishes
  (add-hook 'TeX-after-compilation-finished-functions
	    #'TeX-revert-document-buffer)

  (add-hook 'LaTeX-mode-hook
	    (lambda ()
	      (add-hook 'after-save-hook #'TeX-command-run-all nil t))))

(use-package magit
  :ensure t
  :bind
  ("C-x g" . magit-status)
  :config
  (setq magit-save-repository-buffers 'dontask)
  (setq magit-tramp-pipe-stty-settings 'pty)
  (setq magit-refresh-status-buffer nil)
  (setq magit-commit-show-diff nil)
  (setq magit-revert-status-buffers nil)
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("v v" . magit-status)
     '("v C" . magit-clone)
     '("v P" . magit-push)
     '("v F" . magit-pull-from-upstream)
     '("v l" . magit-log-all)
     '("v L" . magit-log-current)
     '("v B" . magit-blame)
     '("v d" . magit-diff-buffer-file)
     '("v a" . magit-file-stage)
     '("v u" . magit-file-unstage)
     '("v m" . magit-dispatch)
     '("v c" . magit-commit-create)
     '("v M" . magit-file-dispatch))))

(defun display-buffer-my-bottom-buffer-p (buffer-name _action)
  "Match compilation and async-shell-command buffers."
  (let ((name (if (bufferp buffer-name)
                  (buffer-name buffer-name)
                buffer-name)))
    (or (string= name "*compilation*")
        (string= name "*Async Shell Command*"))))

(setq switch-to-buffer-obey-display-actions t)
(setq display-buffer-alist
      '(("\\*Help\\*"
         (display-buffer-reuse-window
          display-buffer-pop-up-window)
         (inhibit-same-window . t))
        ((major-mode . magit-status-mode)
         (display-buffer-in-side-window)
         (side . bottom)
         (slot . 0)
         (window-height . 0.3))
        ((major-mode . dired-mode)
         (display-buffer-reuse-window display-buffer-in-side-window)
         (side . left)
         (slot . 0)
         (window-width . 0.3)
         (inhibit-same-window . t))
        (display-buffer-my-bottom-buffer-p
         (display-buffer-in-side-window)
         (side . bottom)
         (slot . 0)
         (window-height . 0.3))
        ("\\*Agenda Commands\\*"
         (display-buffer-in-side-window)
         (side . bottom)
         (slot . 0)
         (window-height . 0.35))))

(setq org-agenda-window-setup 'other-frame)

;; Meow & Keybindings
(defun meow-setup ()
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
  (meow-motion-define-key
   '("j" . meow-next)
   '("k" . meow-prev)
   '("<escape>" . ignore))
  (meow-leader-define-key
   ;; Use SPC (0-9) for digit arguments.
   '("1" . meow-digit-argument)
   '("2" . meow-digit-argument)
   '("3" . meow-digit-argument)
   '("4" . meow-digit-argument)
   '("5" . meow-digit-argument)
   '("6" . meow-digit-argument)
   '("7" . meow-digit-argument)
   '("8" . meow-digit-argument)
   '("9" . meow-digit-argument)
   '("0" . meow-digit-argument)
   '("/" . meow-keypad-describe-key)
   '("?" . meow-cheatsheet))
  (meow-normal-define-key
   '("0" . meow-expand-0)
   '("9" . meow-expand-9)
   '("8" . meow-expand-8)
   '("7" . meow-expand-7)
   '("6" . meow-expand-6)
   '("5" . meow-expand-5)
   '("4" . meow-expand-4)
   '("3" . meow-expand-3)
   '("2" . meow-expand-2)
   '("1" . meow-expand-1)
   '("-" . negative-argument)
   '(";" . meow-reverse)
   '("," . meow-inner-of-thing)
   '("." . meow-bounds-of-thing)
   '("[" . meow-beginning-of-thing)
   '("]" . meow-end-of-thing)
   '("a" . meow-append)
   '("A" . meow-open-below)
   '("b" . meow-back-word)
   '("B" . meow-back-symbol)
   '("c" . meow-change)
   '("d" . meow-delete)
   '("D" . meow-backward-delete)
   '("e" . meow-next-word)
   '("E" . meow-next-symbol)
   '("f" . meow-find)
   '("g" . meow-cancel-selection)
   '("G" . meow-grab)
   '("h" . meow-left)
   '("H" . meow-left-expand)
   '("i" . meow-insert)
   '("I" . meow-open-above)
   '("j" . meow-next)
   '("J" . meow-next-expand)
   '("k" . meow-prev)
   '("K" . meow-prev-expand)
   '("l" . meow-right)
   '("L" . meow-right-expand)
   '("m" . meow-join)
   '("n" . meow-search)
   '("o" . meow-block)
   '("O" . meow-to-block)
   '("p" . meow-yank)
   '("q" . meow-quit)
   '("Q" . meow-goto-line)
   '("r" . meow-replace)
   '("R" . meow-swap-grab)
   '("s" . meow-kill)
   '("t" . meow-till)
   '("u" . meow-undo)
   '("U" . meow-undo-in-selection)
   '("v" . meow-visit)
   '("w" . meow-mark-word)
   '("W" . meow-mark-symbol)
   '("x" . meow-line)
   '("X" . meow-goto-line)
   '("y" . meow-save)
   '("Y" . meow-sync-grab)
   '("z" . meow-pop-selection)
   '("<" . meow-indent)
   '("'" . repeat)
   '("<escape>" . ignore)))

(use-package meow
    :ensure t
    :config
    (setq meow-use-clipboard t)
    (meow-global-mode 1)
    (meow-setup))

(with-eval-after-load 'meow
  (meow-leader-define-key
   '("w h" . windmove-left)
   '("w j" . windmove-down)
   '("w k" . windmove-up)
   '("w l" . windmove-right)
   '("w d" . toggle-window-dedicated)
   '("w q" . delete-window)
   '("w v" . split-window-right)
   '("w s" . split-window-below)
   '("w K" . kill-current-buffer)
   '("w Q" . delete-frame)
   '("w f" . delete-other-windows) ;; focus!
   '("w F" . make-frame)
   '("w r" . revert-buffer-quick)
   '("w S h" . windmove-swap-states-left)
   '("w S j" . windmove-swap-states-down)
   '("w S k" . windmove-swap-states-up)
   '("w S l" . windmove-swap-states-right)))

(global-set-key (kbd "C-x C-d") #'dired)

(with-eval-after-load 'meow
  (meow-leader-define-key
   '("b j" . bookmark-jump)
   '("b m" . bookmark-set)
   '("b l" . bookmark-bmenu-list)))

(setq org-agenda-span 'week)
(add-hook 'emacs-startup-hook (lambda () (org-agenda-list)))

(setq org-directory "~/Documents/orgfiles/")
(setq org-agenda-files (list org-directory))
(setq org-default-notes-file (concat org-directory "/notes.org"))
(setq org-capture-templates
      `(("t" "Todo" entry
	       (file+headline "tasks.org" "Tasks")
         "* TODO %? %^G\nSCHEDULED: %^t\n%U\n  %i\n  %a"
	       :empty-lines 1)
        ("j" "Journal" entry
	       (file+olp+datetree "journal.org")
         "* %?\nEntered on %U\n  %i"
	       :empty-lines 1)
	      ("n" "Note" entry
	       (file "notes.org")
	       "* %^{Title}\n  %U\n  %a"
	       :empty-lines 1)
	      ("s" "Seminar" entry
	       (file "seminars.org")
	       ,(concat "%[" (file-name-concat org-directory "templates" "seminars.org") "]")
         :empty-lines 1)
        ("w" "Weekly research note"
         entry
         (file "research-weekly.org")
         ,(concat
           "* %<%G-W%V> — %^{Topic}\n"
           ":PROPERTIES:\n"
           ":DATE: %u\n"
           ":END:\n\n"
           "** Objective\n\n%?\n\n"
           "** Work Log\n\n"
           "** Findings\n\n"
           "** Problems\n\n"
           "** Next Week\n\n"
           "- [ ] ")
         :empty-lines 1)))

(with-eval-after-load 'org-clock
  (setq org-clock-persist t)
  (org-clock-persistence-insinuate)
  (setq org-clock-auto-clock-resolution 'when-no-clock-is-running))

(with-eval-after-load 'meow
  (meow-leader-define-key
   '("o c" . org-capture)
   '("o a" . org-agenda)
   '("o l" . org-store-link)
   '("o b" . org-switchb)))

(use-package vterm
  :ensure t
  :hook (vterm-mode . meow-insert))

(use-package vertico
  :ensure t
  :init
  (vertico-mode 1)
  :config
  (setq vertico-cycle t))

(use-package orderless
  :ensure t
  :config
  (setq orderless-matching-styles '(orderless-prefixes))
  (setq completion-ignore-case t)
  (setq completion-styles '(basic substring initials orderless))
  (setq completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :ensure t
  :init
  (marginalia-mode 1))

(use-package corfu
  :ensure t
  :custom
  (corfu-auto t)                 ;; Enable auto completion
  (corfu-auto-delay 0.2)         ;; Delay in seconds before popup appears
  (corfu-auto-prefix 2)          ;; Minimum length of prefix to trigger popup
  (corfu-cycle t)                ;; Enable cycling through candidates
  (corfu-preselect 'prompt)      ;; Always preselect the prompt by default
  :config
  (corfu-popupinfo-mode 1)
  :init
  (global-corfu-mode 1))

(setq tab-always-indent 'complete)

(use-package cape
  :defer 1
  :config
  (add-hook 'completion-at-point-functions #'cape-dabbrev 20) ; words from buffer
  (add-hook 'completion-at-point-functions #'cape-file 20))

(use-package consult
  :ensure t
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("s l" . consult-line)
     '("s r" . consult-ripgrep)
     '("s b" . consult-buffer)
     '("s i" . consult-imenu)
     '("s o" . consult-org-agenda)
     '("s h" . consult-org-heading)
     '("s f" . consult-fd))))

(use-package eglot
  :ensure nil
  :hook ((python-ts-mode rust-ts-mode tuareg-mode nael-mode) . eglot-ensure)
  :config
  (eglot-inlay-hints-mode -1)
  (setq treesit-font-lock-level 4)
  (add-to-list 'eglot-server-programs
               '(python-ts-mode . ("uv" "tool" "run" "ty" "server")))
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("e d" . xref-find-definitions)
     '("e r" . xref-find-references)
     '("e o" . xref-go-back)
     '("e a" . eglot-code-actions)
     '("e R" . eglot-rename))))

(setq major-mode-remap-alist
      '((python-mode . python-ts-mode)
	(c-mode . c-ts-mode)
	(rust-mode . rust-ts-mode))) ;; Use treesitter modes as default

;; Rust
(use-package rust-mode
  :ensure t
  :config
  (setq rust-format-on-save t))

;; ml
(use-package tuareg :ensure t)

;; Lean4
(use-package lean4-mode
  :commands lean4-mode
  :vc (:url "https://github.com/leanprover-community/lean4-mode.git"
       :rev :last-release))

;; Dafny
(use-package boogie-friends
  :ensure t
  :hook
  (dafny-mode . (lambda () (prettify-symbols-mode -1))))

(use-package treesit-fold
  :ensure t
  :init
  ;; Bind fold commands under Meow's leader key (SPC z ...)
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("z z" . treesit-fold-toggle)
     '("z o" . treesit-fold-open)
     '("z c" . treesit-fold-close)
     '("z m" . treesit-fold-close-all)
     '("z r" . treesit-fold-open-all)
     '("z R" . treesit-fold-open-recursively)))
  :config
  (setq treesit-fold-line-count-show t)
  (global-treesit-fold-mode 1)
  (global-treesit-fold-indicators-mode 1))

(use-package projectile
  :ensure t
  :init
  (projectile-mode 1)
  :config
  (setq projectile-completion-system 'default))

(use-package consult-projectile
  :ensure t
  :after (projectile consult)
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     ;; Consult-powered project navigation (with Vertico previews)
     '("p p" . consult-projectile-switch-project)
     '("p f" . consult-projectile-find-file)
     '("p b" . consult-projectile-switch-to-buffer)
     '("p B" . projectile-ibuffer)
     '("p P" . consult-projectile)              ;; Multi-source project view
     
     ;; Core Projectile utilities
     '("p s" . projectile-ripgrep)              ;; Search project with ripgrep
     '("p d" . projectile-find-dir)
     '("p r" . projectile-recentf)
     '("p k" . projectile-kill-buffers)
     '("p c" . projectile-compile-project)
     '("p !" . projectile-run-shell-command-in-root)
     '("p &" . projectile-run-async-shell-command-in-root))))

;; Log-in to OpenAI with (gptel-openai-oauth-login)
(use-package gptel
  :ensure t
  :config
  (setq gptel-display-buffer-action
        '((display-buffer-reuse-window display-buffer-in-direction)
          (direction . right)
          (window-width . 0.35)
          (inhibit-same-window . t)))
  (setq gptel-backend
        (gptel-make-openai-oauth "ChatGPT"))
  (setq gptel-default-mode 'org-mode)
  (setq gptel-model "gpt-5.6-luna")
  (setq gptel-use-tools t)
(setq gptel-system-prompt
      (concat
       "You are a large language model living in Emacs and a helpful assistant. "
       "Read ~/.emacs.d/init.el to understand the current configuration. "
       "Respond concisely."))
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("a s" . gptel)
     '("a a" . gptel-menu)
     '("a c" . gptel-context-add)
     '("a k" . gptel-context-remove-all)
     '("a K" . gptel-abort)
     '("a r" . gptel-rewrite)
     '("a t" . gptel-org-set-topic))))


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

(setq gptel-tools
      (list        
       (gptel-make-tool
        :function (lambda (buffer)
                    (unless (buffer-live-p (get-buffer buffer))
                      (error "Error: buffer %s is not live." buffer))
                    (with-current-buffer  buffer
                      (buffer-substring-no-properties (point-min) (point-max))))
        :name "read_buffer"
        :description "Return the contents of an Emacs buffer"
        :args (list '(:name "buffer"
                            :type "string"
                            :description "The name of the buffer whose contents are to be retrieved"))
        :category "emacs")
       (gptel-make-tool
        :name "list_buffers"
        :function (lambda ()
                    (mapconcat #'buffer-name (buffer-list) "\n"))
        :description "List the names of all existing Emacs buffers."
        :args nil
        :category "emacs")
       (gptel-make-tool
        :name "list_windows"
        :function
        (lambda ()
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
        :description "List all Emacs windows, their frames, buffers, sizes, and positions."
        :args nil
        :category "emacs")
       (gptel-make-tool
        :name "list_frames"
        :function
        (lambda ()
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
        :description "List all existing Emacs frames and their dimensions."
        :args nil
        :category "emacs")
       (gptel-make-tool
        :name "get_current_context"
        :function
        (lambda ()
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
        :description
        "Return the current buffer, file, mode, cursor position, region, and nearby text."
        :args nil
        :category "emacs")
       (gptel-make-tool
        :name "describe_symbol"
        :function
        (lambda (symbol)
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
        :description
        "Describe an Emacs Lisp function, variable, or both."
        :args
        (list '(:name "symbol"
                      :type "string"
                      :description "The name of the function or variable to describe."))
        :category "emacs")

       ;; Magit Tools
       (gptel-make-tool
        :name "magit_git_readonly"
        :function #'my-gptel-magit-git-readonly
        :description
        "Run a read-only Git command through Magit in a local or TRAMP repository.
Allowed commands include status, log, diff, show, branch, and rev-parse."
        :args
        (list
         '(:name "directory"
                 :type "string"
                 :description "Repository directory.")
         '(:name "args"
                 :type "array"
                 :items (:type "string")
                 :description
                 "Git arguments, e.g. [\"status\", \"--short\", \"--branch\"]."))
        :category "git")


       
       (gptel-make-tool
        :function (lambda (directory)
	                  (mapconcat #'identity
                               (directory-files directory)
                               "\n"))
        :name "list_directory"
        :description "List the contents of a given directory"
        :args (list '(:name "directory"
	                          :type "string"
	                          :description "The path to the directory to list"))
        :category "filesystem")
       (gptel-make-tool
        :function (lambda (filepath)
	                  (with-temp-buffer
	                    (insert-file-contents (expand-file-name filepath))
	                    (buffer-string)))
        :name "read_file"
        :description "Read and display the contents of a file"
        :args (list '(:name "filepath"
	                          :type "string"
	                          :description "Path to the file to read.  Supports relative paths and ~."))
        :category "filesystem")))


(use-package rotate
  :ensure t
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("w t" . rotate-layout) ;; transpose
     )))

(use-package diff-hl
  :ensure t
  :init
  (global-diff-hl-mode)
  :config
  ;; Update indicators dynamically as you type (instead of only on save)
  (diff-hl-flydiff-mode 1))

(use-package winpulse
  :vc (:url "https://github.com/xenodium/winpulse"
       :rev :newest)
  :config
  (winpulse-mode +1))
