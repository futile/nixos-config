{ inputs, lib, ... }:
{ config, pkgs, ... }:
let
  base-emacs = pkgs.emacs;
  emacs-with-pkgs = (pkgs.emacsPackagesGen base-emacs).emacsWithPackages (epkgs: (with epkgs; [
    vterm
  ]));
  emacs-wrapped-for-doom = lib.mkWrappedWithDeps {
    pkg = emacs-with-pkgs;
    pathsToWrap = [ "bin/emacs" "bin/emacs-*" ];
    deps = with pkgs; [
      ripgrep
      findutils
      fd
      shellcheck
      multimarkdown
      nixfmt
      jq
      editorconfig-core-c

      # for vterm compile module
      cmake
      gnumake
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
