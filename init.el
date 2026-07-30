(setq custom-file "~/.emacs.d/custom.el")
(load custom-file)

(add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
(load-theme 'lauds)

(setq inhibit-startup-screen t)
(tool-bar-mode 0)
(scroll-bar-mode 0)
(global-display-line-numbers-mode 1)
(global-visual-line-mode -1)
(blink-cursor-mode -1)
(pixel-scroll-precision-mode 1)

(defalias 'list-buffers 'ibuffer)
(setq ibuffer-saved-filter-groups
      '(("default"
	 ("dired" (mode . dired-mode)))
	 ("magit" (name . "^magit"))))
(add-hook 'ibuffer-mode-hook
	  (lambda ()
	    (ibuffer-switch-to-saved-filter-groups "default")))

(set-face-attribute 'default nil
                    :family "JetBrains Mono"
                    :height 160
                    :weight 'regular
                    :slant 'normal)

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(setq show-trailing-whitespace t)

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
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
      '("v v" . magit-status))))

(use-package autorevert
  :ensure nil ; built-in
  :config
  (setq auto-revert-remote-files t)
  (global-auto-revert-mode 1))

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
   '("'" . repeat)
   '("<escape>" . ignore)))

(use-package meow
    :ensure t
    :config
    (setq meow-use-clipboard t)
    (meow-global-mode 1)
    (meow-setup))

(global-set-key (kbd "C-d") #'View-scroll-half-page-forward)
(global-set-key (kbd "C-k") #'View-scroll-half-page-backward)

(with-eval-after-load 'meow
  (meow-leader-define-key
   '("w h" . windmove-left)
   '("w j" . windmove-down)
   '("w k" . windmove-up)
   '("w l" . windmove-right)
   '("w q" . delete-window)
   '("w v" . split-window-right)
   '("w s" . split-window-below)
   '("w K" . kill-buffer)
   '("w f" . delete-other-windows)
   '("w F" . make-frame)))

(global-set-key (kbd "C-x C-d") #'dired)

(defvar my-bookmark-map (make-sparse-keymap) "Bookmark keymap.")
(global-set-key (kbd "C-c B") my-bookmark-map)

(define-key my-bookmark-map (kbd "j") #'bookmark-jump)
(define-key my-bookmark-map (kbd "m") #'bookmark-set)
(define-key my-bookmark-map (kbd "l") #'bookmark-bmenu-list)


(setq org-directory "~/Documents/orgfiles/")
(setq org-agenda-files (list org-directory))
(setq org-default-notes-file (concat org-directory "/notes.org"))
(setq org-capture-templates
      '(("t" "Todo" entry (file+headline "tasks.org" "Tasks")
         "* TODO %? %^G\nSCHEDULED: %^t\n%U\n  %i\n  %a")
        ("j" "Journal" entry (file+olp+datetree "journal.org")
         "* %?\nEntered on %U\n  %i\n  %a")
	("n" "Note" entry (file "notes.org") "* %?\n%U\n%a\n")))

(with-eval-after-load 'meow
  (meow-leader-define-key
   '("o c" . org-capture)
   '("o a" . org-agenda)
   '("o l" . org-store-link)
   '("o b" . org-switchb)))

(use-package vertico
  :ensure t
  :init
  (vertico-mode 1)
  :config
  (setq vertico-cycle t))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles basic partial-completion)))))

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
  :init
  (global-corfu-mode 1))

(setq tab-always-indent 'complete)

(use-package cape
  :ensure t
  :config
  ;; Add dabbrev (words in buffer) and file-path completion globally
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev))

(use-package consult
  :ensure t
  :init
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("s l" . consult-line)
     '("s r" . consult-ripgrep)
     '("s b" . consult-buffer)
     '("s i" . consult-imenu)
     '("s g" . consult-git-grep)
     '("s f" . consult-find))))

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

;; Python
(setq major-mode-remap-alist
      '((python-mode . python-ts-mode))) ;; Use python-ts-mode as default

;; Rust
(use-package rust-mode
  :ensure t
  :config
  (setq rust-format-on-save t)
  :hook
  (prettify-symbols-mode))

;; OCaml
(use-package tuareg :ensure t)

;; Lean4
(use-package nael
  :ensure t
  :hook (nael-mode . abbrev-mode))

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
     '("p P" . consult-projectile)              ;; Multi-source project view
     
     ;; Core Projectile utilities
     '("p s" . projectile-ripgrep)              ;; Search project with ripgrep
     '("p d" . projectile-find-dir)
     '("p r" . projectile-recentf)
     '("p k" . projectile-kill-buffers)
     '("p c" . projectile-compile-project)
     '("p !" . projectile-run-shell-command-in-root)
     '("p &" . projectile-run-async-shell-command-in-root))))
