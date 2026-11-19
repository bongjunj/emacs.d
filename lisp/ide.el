;;; ide.el --- Programming support for terminal Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Language servers, diagnostics, and language modes.  Completion uses the
;; CAPF frontend configured in init.el; all UI features work in emacs -nw.

;;; Code:

(require 'use-package)

;; Prefer Tree-sitter modes and their full highlighting independently of LSP.
(setopt treesit-enabled-modes t
        treesit-font-lock-level 4)

(use-package flycheck
  :ensure t
  :demand t
  :bind (:map flycheck-mode-map
              ("M-n" . flycheck-next-error)
              ("M-p" . flycheck-previous-error))
  :custom
  ;; Terminal frames have no fringe.
  (flycheck-indication-mode 'left-margin)
  :config
  (global-flycheck-mode 1)
  (global-flycheck-annotate-mode 1))

(defun bongjun/lsp-python-setup ()
  "Start deferred LSP with ty for the current Python buffer."
  (setq-local lsp-enabled-clients '(ty-ls))
  ;; Keep signature help available on demand via C-c l h s.
  (setq-local lsp-signature-auto-activate nil)
  (lsp-deferred))

(use-package lsp-mode
  :ensure t
  :commands (lsp lsp-deferred)
  :hook ((python-mode . bongjun/lsp-python-setup)
         (python-ts-mode . bongjun/lsp-python-setup)
         (neocaml-base-mode . lsp-deferred))
  :bind (("C-c e e" . lsp)
         :map lsp-mode-map
         ("C-c e a" . lsp-execute-code-action)
         ("C-c e R" . lsp-rename)
         ("C-c e f" . lsp-format-region)
         ("C-c e F" . lsp-format-buffer)
         ("C-c e o" . lsp-organize-imports)
         ("C-c e q" . lsp-workspace-shutdown))
  :init
  ;; Set this before lsp-mode constructs its keymap; Super is awkward in a TTY.
  (setq lsp-keymap-prefix "C-c l")
  :custom
  (lsp-diagnostics-provider :flycheck)
  (lsp-completion-provider :capf)
  (lsp-completion-enable t)
  ;; Keep the file header configured in init.el.
  (lsp-headerline-breadcrumb-enable nil)
  (lsp-python-ty-clients-server-command '("uv" "tool" "run" "ty" "server"))
  (lsp-ocaml-lsp-server-command '("opam" "exec" "--" "ocamllsp")))

(use-package lsp-ui
  :ensure t
  :hook (lsp-mode . lsp-ui-mode)
  :bind (:map lsp-ui-mode-map
              ("C-c e h" . lsp-ui-doc-show)
              ("C-c e d" . lsp-ui-peek-find-definitions)
              ("C-c e r" . lsp-ui-peek-find-references))
  :custom
  ;; Documentation is an on-demand inline overlay, including in terminal frames.
  (lsp-ui-doc-enable t)
  (lsp-ui-doc-use-childframe nil)
  (lsp-ui-doc-use-webkit nil)
  (lsp-ui-doc-show-with-cursor nil)
  (lsp-ui-doc-show-with-mouse nil)
  (lsp-ui-doc-max-width 80)
  (lsp-ui-doc-max-height 12)
  ;; Flycheck already displays diagnostic messages inline.
  (lsp-ui-sideline-show-diagnostics nil)
  (lsp-ui-sideline-show-hover nil)
  (lsp-ui-sideline-show-symbol nil)
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-sideline-actions-icon nil)
  (lsp-ui-sideline-update-mode 'line)
  (lsp-ui-peek-enable t))

(use-package consult-flycheck
  :ensure t
  :bind ("M-g d" . consult-flycheck))

(use-package consult-lsp
  :ensure t
  :after lsp-mode
  :bind (:map lsp-mode-map
              ("M-g s" . consult-lsp-symbols)))

(use-package markdown-ts-mode
  :ensure nil)

;; OCaml: keep Dune interaction and the OPAM switch menu.
(use-package neocaml
  :ensure t
  :hook (neocaml-base-mode . neocaml-dune-interaction-mode))

(use-package opam-switch-mode
  :ensure t
  :hook (neocaml-base-mode . opam-switch-mode))

;; Lean owns its LSP startup and goal display.
(use-package lean4-mode
  :vc (:url "git@github.com:leanprover-community/lean4-mode.git" :rev :last-release)
  :config
  (remove-hook 'lean4-mode-hook #'lsp)
  (add-hook 'lean4-mode-hook #'lsp-deferred)
  ;; Inlay hints are disabled; acknowledge Lean's refresh requests.
  (puthash "workspace/inlayHint/refresh"
           (lambda (_workspace _params) nil)
           (lsp--client-request-handlers
            (gethash 'lean4-lsp lsp-clients))))

;; Dafny retains the Flycheck integration supplied by boogie-friends.
(use-package dash :ensure t)
(use-package boogie-friends
  :ensure t
  :after dash
  :hook (dafny-mode . (lambda () (prettify-symbols-mode -1))))

(provide 'ide)
;;; ide.el ends here
