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
      python38 # until python-language-server can handle 3.9 by default
    ];
    suffix-deps = with pkgs; [
      shellcheck
      multimarkdown
      nixfmt
      jq
      editorconfig-core-c
      unstable.python-language-server

      # for pyls installation
      # unzip
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
