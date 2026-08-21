;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(setq custom-file "~/.emacs.d/custom.el")
;; (load custom-file nil nil)
(global-set-key (kbd "<C-pinch>") #'ignore)
(global-set-key (kbd "<C-wheel-up>") #'ignore)
(global-set-key (kbd "<C-wheel-down>") #'ignore)

(setq browse-url-browser-function 'browse-url-default-browser)
;; (setq default-frame-alist '((width . 80) (height . 45)))

(add-to-list 'load-path (file-name-concat user-emacs-directory "lisp"))
(require 'tools)
(require 'util)

(setq vc-handled-backends '(Git))
(setq confirm-kill-emacs 'yes-or-no-p)
(setq auto-save-default nil)
(setq inhibit-startup-screen t)
(tool-bar-mode 0)
(scroll-bar-mode 0)
(menu-bar-mode -1)
(global-display-line-numbers-mode 1)
(global-visual-line-mode -1)
(toggle-truncate-lines)
(blink-cursor-mode -1)
(global-auto-revert-mode)
(winner-mode 1)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)
(setq compilation-scroll-output t)

(setq frame-title-format
      '(buffer-file-name "%b - %f"
        (dired-directory dired-directory
         ("%b - Dir: " default-directory))))

;; TRAMP Optimization: https://coredumped.dev/2025/06/18/making-tramp-go-brrrr./
(setq remote-file-name-inhibit-locks t
      tramp-use-scp-direct-remote-copying t
      remote-file-name-inhibit-auto-save-visited t)

(setq tramp-copy-size-limit (* 1024 1024) ;; 1MB
      tramp-verbose 2)

(setq tramp-default-method "ssh")

(connection-local-set-profile-variables
 'remote-direct-async-process
 '((tramp-direct-async-process . t)))

(connection-local-set-profiles
 '(:application tramp :protocol "ssh")
 'remote-direct-async-process)

(setq magit-tramp-pipe-stty-settings 'pty)

(with-eval-after-load 'tramp
  (with-eval-after-load 'compile
    (remove-hook 'compilation-mode-hook #'tramp-compile-disable-ssh-controlmaster-options)))

;; visual indicator at the column of width 80
(setopt display-fill-column-indicator-column 80)
(add-hook 'prog-mode-hook
          (lambda () (display-fill-column-indicator-mode 1)))
(add-hook 'markdown-mode-hook
          (lambda () (display-fill-column-indicator-mode 1)))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Meow & Keybindings
(defun meow-setup ()
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
  (meow-motion-define-key
   '("h" . meow-left)
   '("j" . meow-next)
   '("k" . meow-prev)
   '("l" . meow-right)
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

(defalias 'list-buffers 'ibuffer)
(use-package ibuffer-project
  :ensure t
  :after ibuffer
  :config
  ;; Cache project detection when possible.
  (setq ibuffer-project-use-cache t)

  ;; Generate groups whenever Ibuffer is opened.
  (add-hook 'ibuffer-mode-hook
            (lambda ()
              (setq-local ibuffer-filter-groups
                          (ibuffer-project-generate-filter-groups)))))

(setq show-trailing-whitespace t)

(set-face-attribute 'default nil
                    :family "Iosevka"
                    :height 160
                    :weight 'regular
                    :slant 'normal)

(use-package dired
  :ensure nil ;; built-tin
  :hook
  (dired-mode . dired-hide-details-mode))

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
	      (add-hook 'after-save-hook
                  (lambda ()
                    (TeX-command-run-all nil))
                  nil t))))

(use-package pdf-tools
  :ensure t
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :hook
  (pdf-view-mode . (lambda () (display-line-numbers-mode -1)))
  :config
  (pdf-tools-install)
  (setq-default pdf-view-display-size 'fit-page))

(defun bongjun/meow-leader-define-key (&rest bindings)
  "Define Meow leader BINDINGS after Meow has loaded."
  (with-eval-after-load 'meow
    (apply #'meow-leader-define-key bindings)))

(use-package magit
  :ensure t
  :bind
  ("C-x g" . magit-status)
  :config
  (setq magit-save-repository-buffers 'dontask)
  (setq magit-tramp-pipe-stty-settings 'pty)
  (setq magit-branch-direct-configure nil)
  (setq magit-refresh-status-buffer nil)
  (setq magit-commit-show-diff nil)
  (setq magit-revert-status-buffers nil)
  (define-key magit-status-mode-map (kbd "K") #'magit-discard)
  :init
  (bongjun/meow-leader-define-key
   '("v v" . magit-status)
   '("v C" . magit-clone)
   '("v P" . magit-push)
   '("v F" . magit-pull-from-upstream)
   '("v l" . magit-log-all)
   '("v L" . magit-log-current)
   '("v B" . magit-blame)
   '("v d" . magit-diff-buffer-file)
   '("v a" . magit-file-stage)
   '("v h" . diff-hl-show-hunk)
   '("v s" . diff-hl-stage-dwim)
   '("v u" . magit-file-unstage)
   '("v ]" . diff-hl-next-hunk)
   '("v [" . diff-hl-previous-hunk)
   '("v m" . magit-dispatch)
   '("v c" . magit-commit-create)
   '("v M" . magit-file-dispatch)))


;;; Controls how to display buffers
(setq switch-to-buffer-obey-display-actions nil)
(setq switch-to-buffer-in-dedicated-window 'pop)
(setq display-buffer-alist
      '(("\\*Help\\*"
         (display-buffer-reuse-window
          display-buffer-pop-up-window)
         (inhibit-same-window . t))

        ("\\*\\(?:compilation\\|Async Shell Command\\)\\*"
         (display-buffer-in-side-window
          display-buffer-reuse-window)
         (side . bottom)
         (slot . -1)
         (window-min-height . 0.35))

        ("\\*Org todo\\*"
         (display-buffer-below-selected)
         (side . bottom)
         (slot . 2))))

(with-eval-after-load 'dired
  (with-eval-after-load 'meow
    (define-key dired-mode-map (kbd "K") #'dired-kill-subdir)))

(bongjun/meow-leader-define-key
 '("w w" . other-window)
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
 '("w f" . select-frame-by-name)
 '("w F" . make-frame)
 '("w r" . revert-buffer-quick))

(use-package org
  :ensure nil ;; built-in
  :init
  (setq org-agenda-span 'week)
  (setq org-directory "~/Documents/orgfiles/")
  (setq org-agenda-window-setup 'current-window)
  (setq org-agenda-files (list org-directory))
  :config
  (setq org-blank-before-new-entry
        '((heading . t)
          (plain-list-item . nil)))
  (setq org-M-RET-may-split-line '((default . nil)))
  (setq org-insert-heading-respect-content t)
  (setq org-log-done 'time)
  (setq org-log-into-drawer t)
  (setq org-todo-keywords
        '((sequence "TODO(t)" "|" "DONE(d!)" "CANCELLED(c!)")))
  (setq org-refile-targets
        '((nil :maxlevel . 3)
          (org-agenda-files :maxlevel . 3)))
  (setq org-outline-path-complete-in-steps nil)
  (setq org-refile-use-outline-path 'file)
  (setq org-default-notes-file (concat org-directory "notes.org"))
  (setq org-capture-templates
        `(("t" "Todo" entry
	         (file+headline "tasks.org" "Inbox")
           "* TODO %? %^G\nDEADLINE: %^t\n%U\n  %i\n  %a"
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
           (file "research.org")
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
    (bongjun/meow-leader-define-key
     '("o c" . org-capture)
     '("o a" . org-agenda)
     '("o l" . org-store-link)
     '("o s" . consult-org-agenda)
     '("o h" . consult-org-heading)
     '("o b" . org-switchb))
  :hook
  (emacs-startup . org-agenda-list))

(use-package vterm
  :ensure t
  :config
  (setq vterm-shell (executable-find "bash"))
  :hook
  ((vterm-mode . (lambda ()
                   (display-line-numbers-mode -1)))
   (vterm-mode . (lambda () (meow-mode -1)))))

(with-eval-after-load 'meow
  (add-hook 'meow-mode-state-list '(vterm-mode . ignore)))

(use-package vertico
  :ensure t
  :init
  (vertico-mode 1)
  :config
  (setq vertico-cycle t)
  (setq vertico-count 6))

(use-package orderless
  :ensure t
  :config
  (setq orderless-matching-styles '(orderless-prefixes))
  (setq completion-ignore-case t
        completion-styles '(basic substring initials orderless))
        completion-category-overrides '((file (styles basic partial-completion))))

(use-package marginalia
  :ensure t
  :init
  (marginalia-mode 1))

(use-package corfu
  :ensure t
  :init
  (setq tab-always-indent 'complete)
  :config
  (setq corfu-preview-current nil)
  (setq corfu-min-width 20)

  (setq corfu-popupinfo-delay '(1.25 . 0.5))
  (corfu-popupinfo-mode 1) ; shows documentation after `corfu-popupinfo-delay'

  (global-corfu-mode 1)

  ;; I also have (setq tab-always-indent 'complete) for TAB to complete
  ;; when it does not need to perform an indentation change.
  (define-key corfu-map (kbd "<tab>") #'corfu-complete)

  ;; Sort by input history (no need to modify `corfu-sort-function').
  (with-eval-after-load 'savehist
    (corfu-history-mode 1)
    (add-to-list 'savehist-additional-variables 'corfu-history)))

(use-package cape
  :ensure t
  :after corfu
  :config
  ;; This is for the global value.
  (setq completion-at-point-functions '(cape-dabbrev cape-file))

  (defun prot/cape-super-set-local (capfs &optional individual-capfs)
    "Set `completion-at-point-functions' to current value plus CAPFS.
Treat CAPFS and the default value as a super CAPF.  Then append the
INDIVIDUAL-CAPFS to the list."
    (let* ((all-for-super (append completion-at-point-functions capfs))
           (all-minus-global (delq t all-for-super))
           (cape-super (apply #'cape-capf-super all-minus-global)))
      (setq-local completion-at-point-functions (append (list cape-super) individual-capfs (list t)))))

  (defun prot/cape-prog-setup ()
    "Set up Cape for programming."
    (prot/cape-super-set-local '(cape-dabbrev) '(cape-file)))

  (add-hook 'prog-mode-hook #'prot/cape-prog-setup)

  (defun prot/cape-text-setup ()
    "Set up Cape for prose."
    (prot/cape-super-set-local '(cape-dict cape-dabbrev cape-emoji) '(cape-file)))

  (add-hook 'text-mode-hook #'prot/cape-text-setup))

(use-package consult
  :ensure t
  :config
  (setq recentf-max-saved-items 200)
  :init
  (recentf-mode 1)
  (bongjun/meow-leader-define-key
     '("s l" . consult-line)
     '("s d" . consult-flymake)
     '("s B" . consult-bookmark)
     '("s s" . consult-recent-file)
     '("s y" . consult-yank-pop)
     '("s k" . consult-yank-from-kill-ring)
     '("s K" . consult-yank-replace)
     '("s g" . consult-ripgrep)
     '("s r" . consult-register-store)
     '("s R" . consult-register)
     '("s b" . consult-buffer)
     '("s i" . consult-imenu)
     '("s f" . consult-fd)))

(setq register-preview-delay 0.8
      register-preview-function #'consult-register-format)

(bongjun/meow-leader-define-key
   '("r r" . point-to-register)
   '("r s" . copy-to-register)
   '("r i" . insert-register)
   '("r m" . bookmark-set))

(use-package eglot
  :ensure nil
  :config
  (setq eglot-prefer-plaintext t
        eglot-send-changes-idle-time 1.0)
  (setq eglot-events-buffer-config '(:size 10000 :format full))
  (setq treesit-font-lock-level 4)
  (add-to-list
   'eglot-server-programs
   '(python-ts-mode . ("uv" "tool" "run" "ty" "server")))
  (bongjun/meow-leader-define-key
     '("e e" . eglot)
     '("e q" . eglot-shutdown)
     '("e I" . eglot-inlay-hints-mode)
     '("e d" . xref-find-definitions)
     '("e D" . xref-find-definitions-other-window)
     '("e r" . xref-find-references)
     '("e b" . xref-go-back)
     '("e f" . xref-go-forward)
     '("e a" . eglot-code-actions)
     '("e R" . eglot-rename)
     '("e g" . flymake-show-buffer-diagnostics)))

(use-package flymake
  :ensure nil
  :config
  (setq flymake-no-changes-timeout 1.0))

;; use treesitters as default
(setq major-mode-remap-alist
      '((python-mode . python-ts-mode)
	      (c-mode . c-ts-mode)
	      (rust-mode . rust-ts-mode)))

(use-package rust-ts-mode
  :ensure t
  :config
  (setq rust-format-on-save t))

;; OCaml
(use-package tuareg
  :ensure t)

(use-package ocaml-eglot
  :ensure t
  :after tuareg
  :hook
  (tuareg-mode . ocaml-eglot))

;; Lean4
(use-package nael
  :vc (:url "https://codeberg.org/mekeor/nael.git"
            :lisp-dir "nael")
  :init
  (setq nael-prepare-lsp nil)
  :mode ("\\.lean\\'" . nael-mode))

;; Dafny
(use-package dash :ensure t)
(use-package boogie-friends
  :ensure t
  :after dash
  :hook
  (dafny-mode . (lambda () (prettify-symbols-mode -1))))

(use-package treesit-fold
  :ensure t
  :init
  ;; Bind fold commands under Meow's leader key (SPC z ...)
  (bongjun/meow-leader-define-key
   '("z z" . treesit-fold-toggle))
  :config
  (setq treesit-fold-line-count-show t)
  (global-treesit-fold-mode 1)
  (global-treesit-fold-indicators-mode 1))

(cl-defmethod project-root ((project (head local)))
  (cdr project))

(defun project-try-local (dir)
  "Determine if DIR is a non-Git project.
DIR must include a .project file to be considered a project."
  (let ((root (locate-dominating-file dir ".project")))
    (and root (cons 'local root))))

(use-package project
  :ensure nil
  :config
  (add-to-list 'project-find-functions #'project-try-local)
  ;; Treat each submodule as a separate project.
  (setq project-vc-merge-submodules nil)
  (setq project-switch-commands
        '((project-dired "Dired")
          (project-find-file "Find file")
          (project-find-regexp "Find regexp")
          (project-eshell "Eshell")
          (project-any-command "Other"))))

(bongjun/meow-leader-define-key
 '("p p" . project-switch-project)
 '("p d" . project-find-dir)
 '("p k" . project-kill-buffers)
 '("p c" . project-compile)
 '("p !" . project-shell-command)
 '("p &" . project-async-shell-command))


(defun my-gptel-project ()
  (interactive)
  (let ((default-directory
         (if-let ((project (project-current)))
             (project-root project)
           default-directory)))
    (call-interactively #'gptel)))

;; Log-in to OpenAI with M-x gptel-openai-oauth-login
(use-package gptel
  :ensure t
  :config
  (setq gptel-backend
        (gptel-make-openai-oauth "ChatGPT"))
  (setq gptel-default-mode 'org-mode)
  (setq gptel-model 'gpt-5.6-luna)
  (setq-default gptel-max-tokens nil)
  (setq gptel-system-prompt
      (concat
       "You are a large language model living in Emacs and a helpful assistant. "
       "If asked about the emacs settings, "
       "read ~/.emacs.d/init.el to understand the current configuration. "
       "Read ./AGENTS.md if exists. "
       "Read existing relevant buffers to understand the context clearly before you answer to the user. "
       "Respond concisely."))
  :init
  (bongjun/meow-leader-define-key
     '("a s" . my-gptel-project)
     '("a a" . gptel-menu)
     '("a c" . gptel-add)
     '("a k" . gptel-context-remove-all)
     '("a K" . gptel-abort)
     '("a r" . gptel-rewrite)))

;; (use-package gptel-annotate
;;   :vc (:url "https://github.com/karthink/gptel-annotate"
;;        :rev :newest)
;;   :after gptel)

(use-package macher
  :ensure t
  :custom
  ;; The org UI has structured conversations and nice content folding.
  (macher-action-buffer-ui 'org)

  :hook
  ;; Set up action buffer behavior to your liking.  Alternately, do
  ;; this more generally in your `gptel-mode-hook'.
  (macher-action-buffer-setup
   . (lambda ()
      ;; Auto-scroll responses.
      (setq-local window-point-insertion-type t)))

  :config
  ;; Recommended - register macher tools and presets with gptel.
  (macher-install)

  ;; Recommended - enable macher infrastructure for tools/prompts in
  ;; any buffer.  (Actions and presets will still work without this.)
  (macher-enable)

  ;; Adjust buffer positioning to taste.
  ;; (add-to-list
  ;;  'display-buffer-alist
  ;;  '("\\*macher:.*\\*"
  ;;    (display-buffer-in-side-window)
  ;;    (side . bottom)))
  ;; (add-to-list
  ;;  'display-buffer-alist
  ;;  '("\\*macher-patch:.*\\*"
  ;;    (display-buffer-in-side-window)
  ;;    (side . right)))
  )

(require 'gptel-annotate)
(require 'gptel-preset-collection)
(require 'gptel-inline)

(setq gptel-tools
      (list
       (gptel-make-tool
        :name "project_shell_command"
        :function #'my-gptel-project-shell-command
        :description
        "Run a shell command from the root of the current Emacs project."
        :args
        (list
         '(:name "command"
                 :type "string"
                 :description "The shell command to run."))
        :category "project"
        :async t
        :confirm t)
       (gptel-make-tool
        :name "describe_symbol"
        :function #'my-gptel-describe-symbol
        :description
        "Describe an Emacs Lisp function, variable, or both."
        :args
        (list '(:name "symbol"
                      :type "string"
                      :description "The name of the function or variable to describe."))
        :category "emacs")
       (gptel-make-tool
        :name "apropos_elisp"
        :function #'my-gptel-apropos
        :description
        "Find Emacs Lisp functions whose names match a regular expression and return their documentation."
        :args
        (list
         '(:name "regexp"
                 :type "string"
                 :description "Emacs regular expression to match against function names.")
         '(:name "max_results"
                 :type "integer"
                 :optional t
                 :description "Maximum number of matching functions to return; defaults to 50."))
        :category "emacs")))


(use-package rotate
  :ensure t
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("w t" . rotate-layout))))

(use-package diff-hl
  :ensure t
  :init
  (global-diff-hl-mode))

(use-package rmsbolt
  :vc (:url "git@github.com:bongjunj/rmsbolt.git"
       :rev :newest)
  :ensure t
  :config
  (setq rmsbolt-asm-format "intel")
  (setq rmsbolt-automatic-recompile nil))

(use-package modus-themes
  :ensure t
  :demand t
  :init
  ;; Starting with version 5.0.0 of the `modus-themes', other packages
  ;; can be built on top to provide their own "Modus" derivatives.
  ;; For example, this is what I do with my `ef-themes' and
  ;; `standard-themes' (starting with versions 2.0.0 and 3.0.0,
  ;; respectively).
  ;;
  ;; The `modus-themes-include-derivatives-mode' makes all Modus
  ;; commands that act on a theme consider all such derivatives, if
  ;; their respective packages are available and have been loaded.
  ;;
  ;; Note that those packages can even completely take over from the
  ;; Modus themes such that, for example, `modus-themes-rotate' only
  ;; goes through the Ef themes (to this end, the Ef themes provide
  ;; the `ef-themes-take-over-modus-themes-mode' and the Standard
  ;; themes have the `standard-themes-take-over-modus-themes-mode'
  ;; equivalent).
  ;;
  ;; If you only care about the Modus themes, then (i) you do not need
  ;; to enable the `modus-themes-include-derivatives-mode' and (ii) do
  ;; not install and activate those other theme packages.
  (modus-themes-include-derivatives-mode 1)
  :bind
  (("<f5>" . modus-themes-rotate)
   ("C-<f5>" . modus-themes-select)
   ("M-<f5>" . modus-themes-load-random))
  :config
  ;; Your customizations here.  All customizations must evaluated
  ;; BEFORE loading the theme.
  (setq modus-themes-to-toggle '(modus-operandi modus-vivendi)
        modus-themes-to-rotate modus-themes-items
        modus-themes-mixed-fonts nil
        modus-themes-variable-pitch-ui nil
        modus-themes-italic-constructs t
        modus-themes-bold-constructs t
        modus-themes-completions '((t . (bold)))
        modus-themes-prompts '(bold))

  (setq modus-themes-common-palette-overrides nil)

  ;; Finally, load your theme of choice (or a random one with
  ;; `modus-themes-load-random', `modus-themes-load-random-dark',
  ;; `modus-themes-load-random-light').
  (modus-themes-load-theme 'modus-vivendi))

(use-package alert
  :ensure t
  :config
  (setq alert-default-style 'osx-notifier))


(use-package embark
  :ensure t
  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'
  :init

  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Show the Embark target at point via Eldoc. You may adjust the
  ;; Eldoc strategy, if you want to see the documentation from
  ;; multiple providers. Beware that using this can be a little
  ;; jarring since the message shown in the minibuffer can be more
  ;; than one line, causing the modeline to move up and down:

  ;; (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
  ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)

  ;; Add Embark to the mouse context menu. Also enable `context-menu-mode'.
  ;; (context-menu-mode 1)
  ;; (add-hook 'context-menu-functions #'embark-context-menu 100)

  :config

  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

(use-package embark-consult
  :ensure t)

(use-package ace-window
  :ensure t
  :config
  (global-set-key (kbd "M-o") 'ace-window))

(require 'ansi-color)
(defun colorize-compilation-buffer ()
  (ansi-color-apply-on-region compilation-filter-start (point)))
(add-hook 'compilation-filter-hook 'colorize-compilation-buffer)

(use-package tramp-rpc
  :after tramp
  :vc (:url "https://github.com/ArthurHeymans/emacs-tramp-rpc"
       :rev :newest
       :lisp-dir "lisp"))
