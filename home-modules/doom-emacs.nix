{ inputs, lib, ... }:
{ config, pkgs, ... }:
let
  base-emacs = pkgs.unstable.emacs;
  emacs-with-pkgs = (pkgs.unstable.emacsPackagesNgGen base-emacs).emacsWithPackages
    (epkgs: (with epkgs; [ vterm ]));
  emacs-wrapped-for-doom = lib.mkWrappedWithDeps {
    pkg = emacs-with-pkgs;
    pathsToWrap = [ "bin/emacs" "bin/emacs-*" ];
    prefix-deps = with pkgs; [
      ripgrep
      findutils
      fd
    ];
    suffix-deps = with pkgs; [
      # misc
      multimarkdown
      jq
      editorconfig-core-c

      # shell
      shfmt
      shellcheck

      # python
      unstable.python-language-server
      black
      python38Packages.pyflakes
      python38Packages.isort

      # nix
      nixfmt

      # tex
      texlab
    ];
  };
in {
  home = {
    packages = with pkgs; [
      emacs-wrapped-for-doom

      # TODO somehow get this into the wrapper?
      emacs-all-the-icons-fonts
    ];

    sessionPath = [ "$HOME/.emacs.d/bin" ];
  };
}
