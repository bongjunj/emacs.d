(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(load-theme 'tango-dark)
(global-display-line-numbers-mode 1)

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:family "JetBrains Mono" :foundry "nil" :slant normal :weight regular :height 160 :width normal)))))

(setq rust-format-on-save t)
(add-hook 'rust-mode-hook (lambda () (prettify-symbols-mode)))

(setq show-trailing-whitespace t)
(global-completion-preview-mode)

(use-package exec-path-from-shell
  :ensure t
  :init
  (when (memq window-system '(mac ns x pgtk))
  (exec-path-from-shell-initialize)))

(use-package tramp
  :ensure t
  :config
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path))

;; --- 1. AUCTeX Setup ---
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

;; --- 3. PDF Tools Setup ---
(use-package pdf-tools
  :ensure t
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :config
  ;; Initialize PDF Tools (compiles epdfinfo backend on first run)
  (pdf-tools-install)
  ;; Match theme background when reading PDFs
  (setq-default pdf-view-display-size 'fit-width)
  (add-hook 'pdf-view-mode-hook #'pdf-view-auto-slice-minor-mode)

  :hook (pdf-view-mode . (lambda () (display-line-number-mode -1))))

(use-package magit
  :ensure t
  :bind
  ("C-x g" . magit-status))

(use-package autorevert
  :ensure nil ; built-in
  :config
  (setq auto-revert-remote-files t)
  (global-auto-revert-mode 1))

(use-package rust-mode :ensure t)
(use-package tuareg :ensure t)

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

;; Makes C-c w h/j/k/l work everywhere.
(global-set-key (kbd "C-c w") my-window-map)

;; org-mode has C-c w defined. unbind it.
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c w") nil))

(global-set-key (kbd "C-x C-d") #'dired)

(setq org-agenda-files '("~/malloc099@gmail.com - Google Drive/My Drive/org/"))

(defun my-gptel-set-model ()
  (interactive)
  (setq gptel-model (read-string "gptel model: " gptel-model))
  (message "gptel model set to %s" gptel-model))

(use-package gptel
  :ensure t
  :config
  (setq gptel-backend (gptel-make-openai-oauth "ChatGPT"))
  (setq gptel-model "gpt-5.6-luna")

  (define-prefix-command 'my-gptel-prefix)
  (global-set-key (kbd "C-c a") #'my-gptel-prefix)
  (define-key my-gptel-prefix (kbd "RET") #'gptel-send)
  (define-key my-gptel-prefix (kbd "a") #'gptel-context-add))

(setq enable-recursive-minibuffers t)
(minibuffer-depth-indicate-mode 1)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(## auctex boogie-friends codex corfu-terminal exec-path-from-shell
	gnu-elpa-keyring-update gptel kind-icon lv magit markdown-mode
	meow nael orderless pdf-tools pyvenv rust-mode tuareg vertico)))

(use-package nael
  :ensure t
  :hook (nael-mode . abbrev-mode))
