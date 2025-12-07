let
  mkEditorTools =
    pkgs: with pkgs; [
      # misc
      jq
      editorconfig-core-c
      prettier

      # markdown
      multimarkdown
      markdownlint-cli2
      marksman

      # shell
      shfmt
      shellcheck

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
      nodePackages.vscode-json-languageserver

      # js/ts (:
      vtsls
    ];

  # reference: https://discourse.nixos.org/t/wrapping-packages/4431
  mkWrappedWithDeps =
    final: prev:
    {
      pkg,
      pathsToWrap,
      prefix-deps ? [ ],
      suffix-deps ? [ ],
      extraWrapProgramArgs ? [ ],
      otherArgs ? { },
    }:
    let
      prefixBinPath = prev.lib.makeBinPath prefix-deps;
      suffixBinPath = prev.lib.makeBinPath suffix-deps;
    in
    prev.symlinkJoin (
      {
        name = pkg.name + "-wrapped";
        pname = pkg.pname or pkg.name;
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
      }
      // otherArgs
    );

  lib-my-overlay = final: prev: {
    lib = prev.lib // {
      my = {
        editorTools = mkEditorTools final;
        mkWrappedWithDeps = mkWrappedWithDeps final prev;
      };
    };
  };
in
{
  nixpkgs.overlays = [ lib-my-overlay ];
}
