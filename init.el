(setq inhibit-startup-screen t)
(tool-bar-mode 0)
(scroll-bar-mode 0)
(load-theme 'tango-dark)
(global-display-line-numbers-mode 1)
(global-completion-preview-mode)
(blink-cursor-mode -1)

(set-face-attribute 'default nil
                    :family "JetBrains Mono"
                    :height 140
                    :weight 'regular
                    :slant 'normal)

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(setq show-trailing-whitespace t)

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
  ("C-x g" . magit-status))

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

(defvar my-window-map (make-sparse-keymap)
  "Window navigation keymap.")

(define-key my-window-map (kbd "h") #'windmove-left)
(define-key my-window-map (kbd "j") #'windmove-down)
(define-key my-window-map (kbd "k") #'windmove-up)
(define-key my-window-map (kbd "l") #'windmove-right)
(define-key my-window-map (kbd "q") #'delete-window)
(define-key my-window-map (kbd "v") #'split-window-right)
(define-key my-window-map (kbd "s") #'split-window-below)
(define-key my-window-map (kbd "K") #'kill-buffer)
(define-key my-window-map (kbd "F") #'make-frame)

;; Makes C-c w h/j/k/l work everywhere.
(global-set-key (kbd "C-c w") my-window-map)

;; org-mode has C-c w defined. unbind it.
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c w") nil))

(global-set-key (kbd "C-x C-d") #'dired)

(defvar my-bookmark-map (make-sparse-keymap) "Bookmark keymap.")
(global-set-key (kbd "C-c B") my-bookmark-map)

(define-key my-bookmark-map (kbd "j") #'bookmark-jump)
(define-key my-bookmark-map (kbd "m") #'bookmark-set)
(define-key my-bookmark-map (kbd "l") #'bookmark-bmenu-list)

(setq org-agenda-files '("~/malloc099@gmail.com - Google Drive/My Drive/org/"))

(use-package eglot
  :ensure nil
  :hook ((python-ts-mode rust-ts-mode tuareg-mode nael-mode) . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '(python-ts-mode . ("uv" "tool" "run" "ty" "server"))))

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


