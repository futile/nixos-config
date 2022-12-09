;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Felix Rath"
      user-mail-address "felixm.rath@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; start the initial frame maximized
(add-to-list 'initial-frame-alist '(fullscreen . maximized))

(after! magit
  ;; Copy doom's default but open in a new buffer except for its other conditions
  ;;;###autoload
  (defun magit-display-buffer-fn-mine (buffer)
    "Same as `magit-display-buffer-traditional', except...
- If opened from a commit window, it will open below it.
- Magit process windows are always opened in small windows below the current.
- Everything else will reuse the same window."
    (let ((buffer-mode (buffer-local-value 'major-mode buffer)))
      (display-buffer
       buffer (cond
               ((and (eq buffer-mode 'magit-status-mode)
                     (get-buffer-window buffer))
                '(display-buffer-reuse-window))
               ;; Any magit buffers opened from a commit window should open below
               ;; it. Also open magit process windows below.
               ((or (bound-and-true-p git-commit-mode)
                    (eq buffer-mode 'magit-process-mode))
                (let ((size (if (eq buffer-mode 'magit-process-mode)
                                0.35
                              0.7)))
                  `(display-buffer-below-selected
                    . ((window-height . ,(truncate (* (window-height) size)))))))

               ;; Everything else should reuse the current window.
               ;; ((or (not (derived-mode-p 'magit-mode))
               ;;      (not (memq (with-current-buffer buffer major-mode)
               ;;                 '(magit-process-mode
               ;;                   magit-revision-mode
               ;;                   magit-diff-mode
               ;;                   magit-stash-mode
               ;;                   magit-status-mode))))
               ;;  '(display-buffer-same-window))

               ('(+magit--display-buffer-in-direction))))))

  ;;(setq magit-display-buffer-function #'magit-display-buffer-fn-mine)
  )

(after! lsp-mode
  (setq lsp-rust-analyzer-server-display-inlay-hints t)
  (setq lsp-rust-analyzer-max-inlay-hint-length 40)
  (setq lsp-headerline-breadcrumb-enable t)
  )

;; I use nix's python-language-server package, so adjust for the correct binary name
;; From https://github.com/emacs-lsp/lsp-python-ms#nixos
(after! lsp-python-ms
  (setq lsp-python-ms-executable (executable-find "python-language-server")))

(after! pipenv
  (setq pipenv-with-projectile t))

(after! browse-at-remote
  (add-to-list 'browse-at-remote-remote-type-domains '("laboratory.comsys.rwth-aachen.de" . "gitlab")))

;; for `parent-dir/mod.rs' instead of `mod.rs<2>' etc. buffer names
(after! uniquify
  (setq uniquify-buffer-name-style 'forward))
