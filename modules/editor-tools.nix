pkgs: with pkgs; [
  # misc
  jq
  editorconfig-core-c
  prettier
  taplo

  # markdown
  multimarkdown
  markdownlint-cli2
  marksman

  # shell
  bash-language-server
  shellcheck
  shfmt

  # python
  # python-language-server # outdated, have to use the other one instead
  black
  python3Packages.pyflakes
  python3Packages.isort
  pyright

  # nix
  nil # nix lsp
  nixd # better nix lsp?
  nixfmt
  statix

  # tex
  texlab

  # typst
  # typst-lsp # currently broken due to Rust 1.80 `time`-fallout
  typstyle
  # typst-live

  # scala
  metals

  # dhall
  dhall-lsp-server # currently (2023-08-19) broken

  # lua
  stylua
  lua-language-server

  # copilot
  nodejs

  # jsonls
  vscode-json-languageserver

  # js/ts (:
  vtsls
]
