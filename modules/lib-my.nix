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

  # reference: https://discourse.nixos.org/t/wrapping-packages/4431
  mkWrappedWithDeps = final: prev:
    { pkg, pathsToWrap, prefix-deps ? [ ], suffix-deps ? [ ]
    , extraWrapProgramArgs ? [ ], otherArgs ? { } }:
    let
      prefixBinPath = prev.lib.makeBinPath prefix-deps;
      suffixBinPath = prev.lib.makeBinPath suffix-deps;
    in prev.symlinkJoin ({
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
in { nixpkgs.overlays = [ lib-my-overlay ]; }
