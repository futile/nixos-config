let
  mkEditorTools = pkgs:
    with pkgs; [
      # misc
      multimarkdown
      jq
      editorconfig-core-c

      # shell
      shfmt
      shellcheck

      # python
      python-language-server
      black
      python3Packages.pyflakes
      python3Packages.isort

      # nix
      unstable.nil # nix lsp
      nixfmt
      nixpkgs-fmt

      # tex
      texlab

      # scala
      unstable.metals

      # dhall
      unstable.dhall-lsp-server
    ];

  lib-my-overlay = final: prev: {
    lib = prev.lib // { my = { editorTools = mkEditorTools final; }; };
  };
in { nixpkgs.overlays = [ lib-my-overlay ]; }
