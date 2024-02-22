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
      # python-language-server # outdated, have to use the other one instead
      black
      python3Packages.pyflakes
      python3Packages.isort
      ruff-lsp
      nodePackages.pyright

      # nix
      nil # nix lsp
      nixd # better nix lsp?
      nixpkgs-fmt
      # nixfmt # don't want this for now, nixpkgs-fmt is superior :)

      # tex
      texlab

      # typst
      typst-lsp
      typstfmt
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
    ];

  # reference: https://discourse.nixos.org/t/wrapping-packages/4431
  mkWrappedWithDeps = final: prev:
    { pkg
    , pathsToWrap
    , prefix-deps ? [ ]
    , suffix-deps ? [ ]
    , extraWrapProgramArgs ? [ ]
    , otherArgs ? { }
    }:
    let
      prefixBinPath = prev.lib.makeBinPath prefix-deps;
      suffixBinPath = prev.lib.makeBinPath suffix-deps;
    in
    prev.symlinkJoin ({
      name = pkg.name + "-wrapped";
      paths = [ pkg ];
      buildInputs = [ final.makeWrapper ];
      postBuild = ''
        cd "$out"
        for p in ${builtins.toString pathsToWrap}
        do
          wrapProgram "$out/$p" \
            --prefix PATH : "${prefixBinPath}" \
            --suffix PATH : "${suffixBinPath}" \
            ${builtins.toString extraWrapProgramArgs}
        done
      '';
    } // otherArgs);

  lib-my-overlay = final: prev: {
    lib = prev.lib // {
      my = {
        editorTools = mkEditorTools final;
        mkWrappedWithDeps = mkWrappedWithDeps final prev;
      };
    };
  };
in
{ nixpkgs.overlays = [ lib-my-overlay ]; }
