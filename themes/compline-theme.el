;;; compline-theme.el --- Be at peace with the darkness -*- lexical-binding: t; -*-

(deftheme compline
  "A dark, warm, and low-contrast theme built for vanilla Emacs.")

(let ((bg        "#1a1d21")  ; cool slate stone
      (bg-alt    "#22262b")  ; slightly lighter panels
      (base0     "#0f1114")  ; deep background
      (base1     "#171a1e")  ; subtle dark
      (base3     "#282c34")  ; modeline background base
      (base4     "#3d424a")  ; comments & line numbers
      (base5     "#515761")  ; muted gray
      (base6     "#676d77")  ; operators
      (base7     "#8b919a")  ; constants / pure gray
      (base8     "#e0dcd4")  ; keywords & variables
      (fg        "#f0efeb")  ; warm parchment main text
      (fg-alt    "#ccc4b4")  ; muted secondary

      ;; Accent palette
      (red       "#CDACAC")  ; soft warmth
      (orange    "#ccc4b4")  ; hint of sand
      (green     "#b8c4b8")  ; whisper of sage
      (blue      "#b4bcc4")  ; cool steel-grey
      (yellow    "#d4ccb4")  ; warm parchment highlight
      (cyan      "#b4c0c8")  ; hint of ice
      (dark-cyan "#98a4ac")) ; deep water-grey

  (custom-theme-set-faces
   'compline
   ;; Standard UI
   `(default ((t (:background ,bg :foreground ,fg))))
   `(cursor ((t (:background ,fg))))
   `(region ((t (:background ,base4))))
   `(highlight ((t (:background ,base3))))
   `(vertical-border ((t (:foreground "#131619"))))
   `(fringe ((t (:background ,bg))))

   ;; Line numbers
   `(line-number ((t (:foreground ,base4 :background ,bg))))
   `(line-number-current-line ((t (:foreground ,fg :weight bold :background ,bg))))

   ;; Modeline
   `(mode-line ((t (:background ,base1 :foreground ,fg-alt :box (:line-width 4 :color ,base1)))))
   `(mode-line-inactive ((t (:background "#202428" :foreground ,base5 :box (:line-width 4 :color "#202428")))))
   `(mode-line-buffer-id ((t (:foreground ,fg :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,yellow))))

   ;; Font Lock (Syntax Highlighting)
   `(font-lock-builtin-face ((t (:foreground ,cyan))))
   `(font-lock-comment-face ((t (:foreground ,base4 :slant italic))))
   `(font-lock-doc-face ((t (:foreground ,base4 :slant italic))))
   `(font-lock-constant-face ((t (:foreground ,base7))))
   `(font-lock-function-name-face ((t (:foreground ,cyan))))
   `(font-lock-keyword-face ((t (:foreground ,base8 :weight bold))))
   `(font-lock-negation-char-face ((t (:foreground ,red))))
   `(font-lock-number-face ((t (:foreground ,red))))
   `(font-lock-operator-face ((t (:foreground ,base6))))
   `(font-lock-string-face ((t (:foreground ,green))))
   `(font-lock-type-face ((t (:foreground ,blue))))
   `(font-lock-variable-name-face ((t (:foreground ,base8))))
   `(font-lock-warning-face ((t (:foreground ,yellow :weight bold))))

   ;; Org-mode
   `(org-block ((t (:background "#1d2025"))))
   `(org-block-begin-line ((t (:foreground ,base4 :slant italic :background "#17191d"))))
   `(org-ellipsis ((t (:foreground ,red :underline nil))))
   `(org-quote ((t (:background ,base1))))
   `(org-hide ((t (:foreground ,bg))))

   ;; Markdown-mode
   `(markdown-header-face ((t (:foreground ,red :weight bold))))
   `(markdown-markup-face ((t (:foreground ,base5))))
   `(markdown-code-face ((t (:background "#17191d"))))

   ;; Outline headings
   `(outline-1 ((t (:foreground ,fg :weight bold))))
   `(outline-2 ((t (:foreground "#dcdddf"))))
   `(outline-3 ((t (:foreground "#c8cbcf"))))
   `(outline-4 ((t (:foreground ,blue))))
   `(outline-5 ((t (:foreground "#acc1cc"))))
   `(outline-6 ((t (:foreground "#a0b2bd"))))
   `(outline-7 ((t (:foreground "#93a3ad"))))
   `(outline-8 ((t (:foreground ,fg))))))

;; Register the theme in Emacs
(provide-theme 'compline)
;;; compline-theme.el ends here
