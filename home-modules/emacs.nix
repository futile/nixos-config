{ inputs }:
{ config, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      emacs
      # doom dependencies
      ripgrep
      findutils
      fd
      emacs-all-the-icons-fonts
      shellcheck
      multimarkdown
      nixfmt
      jq
      editorconfig-core-c
    ];

    sessionPath = [ "$HOME/.emacs.d/bin" ];
  };
}
