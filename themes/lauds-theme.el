;;; lauds-theme.el --- Welcome the light -*- lexical-binding: t; -*-

(deftheme lauds
  "A light, warm vellum-inspired theme built for vanilla Emacs.")

(let ((bg        "#f0efeb")  ; aged vellum background
      (bg-alt    "#e0dcd4")  ; slightly darker panels
      (base0     "#f5f4f2")  ; soft highlight base
      (base1     "#efeeed")  ; subtle light
      (base3     "#d8d6d3")  ; modeline background base
      (base4     "#b8b5b0")  ; line numbers & secondary UI
      (base5     "#9a9791")  ; comments & muted gray
      (base6     "#7d7a75")  ; keywords
      (base7     "#5f5c58")  ; operators
      (base8     "#2d2a27")  ; deep charcoal foreground accent
      (fg        "#1a1d21")  ; warm charcoal main text
      (fg-alt    "#4a4d51")  ; muted secondary text

      ;; Accent palette
      (red       "#8B6666")  ; dusty rose
      (orange    "#7A6D5A")  ; earth-clay
      (green     "#5A6B5A")  ; olive
      (blue      "#5A6B7A")  ; slate-blue
      (yellow    "#8B7E52")  ; sand-gold
      (teal      "#4D6B6B")  ; sage-grey
      (cyan      "#64757d")) ; grey-water

  (custom-theme-set-faces
   'lauds
   ;; Standard UI
   `(default ((t (:background ,bg :foreground ,fg))))
   `(cursor ((t (:background ,fg))))
   `(region ((t (:background ,base4))))
   `(highlight ((t (:background ,base3))))
   `(vertical-border ((t (:foreground "#d5d4d0"))))
   `(fringe ((t (:background ,bg))))

   ;; Line numbers
   `(line-number ((t (:foreground ,base4 :background ,bg))))
   `(line-number-current-line ((t (:foreground ,fg :weight bold :background ,bg))))

   ;; Modeline
   `(mode-line ((t (:background ,base1 :foreground ,fg-alt :box (:line-width 4 :color ,base1)))))
   `(mode-line-inactive ((t (:background "#d5d1c9" :foreground ,base5 :box (:line-width 4 :color "#d5d1c9")))))
   `(mode-line-buffer-id ((t (:foreground ,fg :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,orange))))

   ;; Font Lock (Syntax Highlighting)
   `(font-lock-builtin-face ((t (:foreground ,cyan))))
   `(font-lock-comment-face ((t (:foreground ,base5 :slant italic))))
   `(font-lock-doc-face ((t (:foreground ,base5 :slant italic))))
   `(font-lock-constant-face ((t (:foreground ,teal))))
   `(font-lock-function-name-face ((t (:foreground ,blue))))
   `(font-lock-keyword-face ((t (:foreground ,base6 :weight bold))))
   `(font-lock-negation-char-face ((t (:foreground ,red))))
   `(font-lock-number-face ((t (:foreground ,orange))))
   `(font-lock-operator-face ((t (:foreground ,base7))))
   `(font-lock-string-face ((t (:foreground ,green))))
   `(font-lock-type-face ((t (:foreground ,blue))))
   `(font-lock-variable-name-face ((t (:foreground ,fg-alt))))
   `(font-lock-warning-face ((t (:foreground ,yellow :weight bold))))

   ;; Org-mode
   `(org-block ((t (:background "#d7d3cb"))))
   `(org-block-begin-line ((t (:foreground ,base4 :slant italic :background "#e6e5e1"))))
   `(org-ellipsis ((t (:foreground ,red :underline nil))))
   `(org-quote ((t (:background ,base1))))
   `(org-hide ((t (:foreground ,bg))))

   ;; Markdown-mode
   `(markdown-header-face ((t (:foreground ,red :weight bold))))
   `(markdown-markup-face ((t (:foreground ,base5))))
   `(markdown-code-face ((t (:background "#e6e5e1"))))

   ;; Outline headings
   `(outline-1 ((t (:foreground ,fg :weight bold))))
   `(outline-2 ((t (:foreground "#303840"))))
   `(outline-3 ((t (:foreground "#475460"))))
   `(outline-4 ((t (:foreground ,blue))))
   `(outline-5 ((t (:foreground "#5c6c77"))))
   `(outline-6 ((t (:foreground "#677580"))))
   `(outline-7 ((t (:foreground "#727e87"))))
   `(outline-8 ((t (:foreground ,fg))))))

;; Register the theme in Emacs
(provide-theme 'lauds)
;;; lauds-theme.el ends here
