;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(setq custom-file "~/.emacs.d/custom.el")
;; (load custom-file nil nil)
(global-set-key (kbd "<C-pinch>") #'ignore)
(global-set-key (kbd "<C-wheel-up>") #'ignore)
(global-set-key (kbd "<C-wheel-down>") #'ignore)

(setq browse-url-browser-function 'eww-browse-url)
(setq default-frame-alist '((width . 170) (height . 45)))

(add-to-list 'load-path (file-name-concat user-emacs-directory "lisp"))
(require 'tools)

(setq vc-handled-backends '(Git))
(setq confirm-kill-emacs 'yes-or-no-p)
(setq auto-save-default nil)
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


(defalias 'list-buffers 'ibuffer)
(setq ibuffer-saved-filter-groups
      '(("default"
	 ("Dired" (mode . dired-mode))
   ("GPTel" (name . "^\\*ChatGPT"))
	 ("Org" (or (mode . org-mode) (mode . org-agenda-mode)))
	 ("magit" (name . "^magit")))))

(add-hook 'ibuffer-mode-hook
	  (lambda ()
	    (ibuffer-switch-to-saved-filter-groups "default")))

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(setq show-trailing-whitespace t)

(set-face-attribute 'default nil
                    :family "Iosevka"
                    :height 160
                    :weight 'regular
                    :slant 'normal)

(set-face-attribute 'variable-pitch nil
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

(use-package pdf-tools
  :ensure t
  :config
  (pdf-tools-install)
  :hook
  (pdf-view-mode . (lambda ()
                     (display-line-numbers-mode -1))))
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
     '("v h" . diff-hl-show-hunk)
     '("v s" . diff-hl-stage-dwim)
     '("v u" . magit-file-unstage)
     '("v ]" . diff-hl-next-hunk)
     '("v [" . diff-hl-previous-hunk)
     '("v m" . magit-dispatch)
     '("v c" . magit-commit-create)
     '("v M" . magit-file-dispatch))))



;;; Controls how to display buffers
(setq switch-to-buffer-obey-display-actions nil)
(setq switch-to-buffer-in-dedicated-window 'pop)
(defun my-command-buffer-p (buffer-name _action)
  "Match compilation and async-shell-command buffers."
  (let ((name (if (bufferp buffer-name)
                  (buffer-name buffer-name)
                buffer-name)))
    (or (string= name "*compilation*")
        (string= name "*Async Shell Command*"))))

(setq display-buffer-alist
      '(("\\*Help\\*"
         (display-buffer-reuse-window
          display-buffer-pop-up-window)
         (inhibit-same-window . t))

        ;; Magit Status
        ((major-mode . magit-status-mode)
         (display-buffer-in-side-window
          display-buffer-reuse-window)
         (side . bottom)
         (slot . 1)
         (window-height 0.25))

        ;; ("COMMIT_EDITMSG"
        ;;  (display-buffer-same-window))

        (my-command-buffer-p
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

(with-eval-after-load 'meow
  (meow-leader-define-key
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
   '("w r" . revert-buffer-quick)))

(global-set-key (kbd "C-x C-d") #'dired)

(with-eval-after-load 'meow
  (meow-leader-define-key
   '("b j" . bookmark-jump)
   '("b m" . bookmark-set)
   '("b l" . bookmark-bmenu-list)))

(use-package org
  :ensure nil ;; built-in
  :init
  (setq org-agenda-span 'week)
  (setq org-directory "~/Documents/orgfiles/")
  (setq org-agenda-window-setup 'current-window)
  (setq org-agenda-files (list org-directory))
  :config
  (setq org-M-RET-may-split-line '((default . nil)))
  (setq org-insert-heading-respect-content t)
  (setq org-log-done 'time)
  (setq org-log-into-drawer t)
  (setq org-todo-keywords
        '((sequence "TODO(t)" "INPROGRESS(i!)" "|" "DONE(d!)" "DELEGATED(D!)" "CANCELLED(c!)")))
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
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("o c" . org-capture)
     '("o a" . org-agenda)
     '("o l" . org-store-link)
     '("o s" . consult-org-agenda)
     '("o h" . consult-org-heading)
     '("o b" . org-switchb)))
  :hook
  (org-mode . (lambda () (display-fill-column-indicator-mode 1)))
  (org-mode . (lambda () (visual-line-mode))))

(add-hook 'emacs-startup-hook (lambda () (org-agenda-list)))

(defvar-local my-vterm-meow-sync-in-progress nil)

(defun my-vterm-sync-meow ()
  (unless my-vterm-meow-sync-in-progress
    (let ((my-vterm-meow-sync-in-progress t))
      (if vterm-copy-mode
          (meow-normal-mode)
        (meow-insert-mode)))))

(defun my-meow-normal-sync-vterm ()
  (when (and (derived-mode-p 'vterm-mode)
             (not vterm-copy-mode)
             (not my-vterm-meow-sync-in-progress))
    (let ((my-vterm-meow-sync-in-progress t))
      (vterm-copy-mode 1))))

(defun my-meow-insert-sync-vterm ()
  (when (and (derived-mode-p 'vterm-mode)
             vterm-copy-mode
             (not my-vterm-meow-sync-in-progress))
    (let ((my-vterm-meow-sync-in-progress t))
      (vterm-copy-mode -1))))

(use-package vterm
  :ensure t
  :hook
  ((vterm-mode . (lambda ()
                   (display-line-numbers-mode -1)))
   (vterm-mode . my-vterm-sync-meow)
   (vterm-copy-mode . my-vterm-sync-meow)))

(with-eval-after-load 'meow
  (add-hook 'meow-normal-mode-hook #'my-meow-normal-sync-vterm)
  (add-hook 'meow-insert-mode-hook #'my-meow-insert-sync-vterm))

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

;; Let's try the built-in completeion-at-point
;; (use-package corfu
;;   :ensure t
;;   :custom
;;   (corfu-auto t)                 ;; Enable auto completion
;;   (corfu-auto-delay 0.2)         ;; Delay in seconds before popup appears
;;   (corfu-auto-prefix 2)          ;; Minimum length of prefix to trigger popup
;;   (corfu-cycle t)                ;; Enable cycling through candidates
;;   (corfu-preselect 'prompt)      ;; Always preselect the prompt by default
;;   :config
;;   (corfu-popupinfo-mode 1)
;;   :init
;;   (global-corfu-mode 1))

(setq tab-always-indent 'complete)

(use-package cape
  :defer 1
  :config
  (add-hook 'completion-at-point-functions #'cape-dabbrev 20) ; words from buffer
  (add-hook 'completion-at-point-functions #'cape-file 20))

(use-package consult
  :ensure t
  :config
  (setq recentf-max-saved-items 200)
  :init
  (recentf-mode 1)
  (with-eval-after-load 'meow
    (meow-leader-define-key
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
     '("s f" . consult-fd))))

(setq register-preview-delay 0.8
      register-preview-function #'consult-register-format)

(with-eval-after-load 'meow
  (meow-leader-define-key
   '("r r" . point-to-register)
   '("r s" . copy-to-register)
   '("r i" . insert-register)
   '("r m" . bookmark-set)))

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
  (with-eval-after-load 'meow
    (meow-leader-define-key
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
     '("e g" . flymake-show-buffer-diagnostics))))

(use-package flymake
  :ensure nil
  :config
  (setq flymake-no-changes-timeout 1.0))

(setq major-mode-remap-alist
      '((python-mode . python-ts-mode)
	(c-mode . c-ts-mode)
	(rust-mode . rust-ts-mode))) ;; Use treesitter modes as default

;; Rust
(use-package rust-mode
  :ensure t
  :config
  (setq rust-format-on-save t))

;; OCaml
(use-package tuareg :ensure t)
(use-package ocaml-eglot
  :ensure t
  :after tuareg
  :hook
  (tuareg-mode . ocaml-eglot))

;; Lean4
(defun my-nael-tab-indent ()
  "Shift the current line, or selected lines, two spaces to the right."
  (interactive)
  (if (use-region-p)
      (let ((beg (save-excursion
                   (goto-char (region-beginning))
                   (line-beginning-position)))
            (end (save-excursion
                   (goto-char (region-end))
                   (line-beginning-position 2))))
        (indent-rigidly beg end 2))
    (indent-rigidly (line-beginning-position)
                    (line-end-position)
                    2)))


(use-package nael
  :vc (:url "https://codeberg.org/mekeor/nael.git"
            :lisp-dir "nael")
  :init
  (setq nael-prepare-lsp nil)
  :mode ("\\.lean\\'" . nael-mode)
  :bind (:map nael-mode-map
              ("TAB" . my-nael-tab-indent)
              ("<tab>" . my-nael-tab-indent)))

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
  (setq project-vc-merge-submodules nil)
  (setq project-switch-commands
        '((project-dired "Dired")
          (project-find-file "Find file")
          (project-find-regexp "Find regexp")
          (project-eshell "Eshell")
          (project-any-command "Other"))))

(defun my-project-consult-ripgrep ()
  "Run `consult-ripgrep` from the current project root."
  (interactive)
  (if-let ((project (project-current)))
      (consult-ripgrep (project-root project))
    (call-interactively #'consult-ripgrep)))

(with-eval-after-load 'meow
    (meow-leader-define-key
     ;; Consult-powered project navigation (with Vertico previews)
     '("p p" . project-switch-project)
     '("p f" . project-find-file)
     '("p b" . project-switch-to-buffer)

     ;; Core Projectile utilities
     '("p g" . my-project-consult-ripgrep)
     '("p d" . project-find-dir)
     '("p k" . project-kill-buffers)
     '("p c" . project-compile)
     '("p !" . project-shell-command)
     '("p &" . project-async-shell-command)))

(defun my-gptel-project ()
  (interactive)
  (let ((default-directory
         (if-let ((project (project-current)))
             (project-root project)
           default-directory)))
    (call-interactively #'gptel)))

;; Log-in to OpenAI with (gptel-openai-oauth-login)
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
       "Read AGENTS.md if the project has the document. "
       "Read existing relevant buffers to understand the context clearly before you answer to the user. "
       "Respond concisely."))
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("a s" . my-gptel-project)
     '("a a" . gptel-menu)
     '("a c" . gptel-add)
     '("a k" . gptel-context-remove-all)
     '("a K" . gptel-abort)
     '("a r" . gptel-rewrite)
     '("a t" . gptel-tools))))


(setq gptel-tools
      (list
       (gptel-make-tool
        :name "project_shell_command"
        :function #'my-gptel-project-shell-command
        :description
        "Run a shell command in the root of the current Emacs project.
This tool requires an active project."
        :args
        (list
         '(:name "command"
                 :type "string"
                 :description "The shell command to run."))
        :category "project"
        :confirm t)
       (gptel-make-tool
        :name "find_file"
        :function #'my-gptel-find-file
        :description "Open a file in an Emacs buffer using find-file-noselect.
First inspect the currently opened buffers before finding a file with this tool.
Use resolved paths against the current default-directory. Only using the basename
will generally result in `File does not found` error.
Returns the buffer name and file information.
Use read_buffer afterward to inspect its contents."
        :args
        (list
         '(:name "filepath"
                 :type "string"
                 :description "Path to the file to open."))
        :category "emacs")
       (gptel-make-tool
        :name "read_file"
        :function #'my-gptel-read-file
        :description
        "Return a selected inclusive line range from a file without visiting it.
Line numbers are 1-based and optional. Relative paths are resolved against
the current GPTel buffer's default-directory. If start_line is omitted,
read from the beginning. If end_line is omitted, read to the end."
        :args
        (list
         '(:name "filepath"
                 :type "string"
                 :description "Path to the file to read.")
         '(:name "start_line"
                 :type "integer"
                 :optional t
                 :description "First line to return, starting at 1.")
         '(:name "end_line"
                 :type "integer"
                 :optional t
                 :description "Last line to return, inclusive."))
        :category "filesystem")
       (gptel-make-tool
        :name "read_buffer"
        :function #'my-gptel-read-buffer
        :description "Return the contents of an Emacs buffer"
        :args (list
               '(:name "buffer"
                       :type "string"
                       :description
                       "The name of the buffer whose contents are to be retrieved"))
        :category "emacs")
       (gptel-make-tool
        :name "edit_buffer"
        :function #'codel-edit-buffer
        :description
        "Replace OLD-STRING to NEW-STRING.
This fails when no match or multiple matches of OLD-STRING found.
This edits the buffer only and does not save the file."
        :args
        (list
         '(:name "buffer"
                 :type "string"
                 :description "Name of the buffer to edit.")
         '(:name "old_string"
                 :type "string"
                 :description "The old string to match against.")
         '(:name "new_string"
                 :type "string"
                 :description "The new string to replace the old string."))
        :category "emacs"
        :confirm t)
       (gptel-make-tool
        :name "replace_buffer"
        :function #'codel-replace-buffer
        :description "Completely replace contents of BUFFER-NAME with CONTENT."
        :args
        (list '(:name "buffer" :type "string" :description "Name of the buffer to replace the content")
              '(:name "content" :type "string" :description "Content to write to the buffer."))
        :category "emacs"
        :confirm t)
       (gptel-make-tool
        :name "save_buffer"
        :function #'my-gptel-save-buffer
        :description
        "Save an Emacs buffer to the file it is visiting."
        :args
        (list
         '(:name "buffer"
                 :type "string"
                 :description "Name of the buffer to save."))
        :category "emacs"
        :confirm t)
       (gptel-make-tool
        :name "list_buffers"
        :function #'my-gptel-list-buffer
        :description "List the names of all existing Emacs buffers."
        :args nil
        :category "emacs")
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
        :category "git")))


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
  (global-diff-hl-mode))

(use-package winpulse
  :vc (:url "https://github.com/xenodium/winpulse"
       :rev :newest)
  :ensure t
  :config
  (winpulse-mode +1))

(use-package rmsbolt
  :vc (:url "git@github.com:bongjunj/rmsbolt.git"
       :rev :newest)
  :ensure t
  :config
  (setq rmsbolt-asm-format "intel")
  (setq rmsbolt-automatic-recompile nil))

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
  (modus-themes-load-theme 'modus-operandi))

(use-package alert
  :ensure t
  :config
  (setq alert-default-style 'osx-notifier))

(use-package autorevert
  :init
  (global-auto-revert-mode))

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

;; Consult users will also want the embark-consult package.
(use-package embark-consult
  :ensure t) ; only need to install it, embark loads it after consult if found


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
