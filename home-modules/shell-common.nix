{ config, lib, pkgs, ... }:

{
  # direnv & nix-direnv
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.fzf = {
    enable = true;

    # use this custom command to ignore hidden and ignored files by default.
    # also follow symlinks, and '$dir' in fish allows prefixes such as `/var/<ctrl-t>` to work.
    fileWidgetCommand = "fd --type f --follow . \\$dir";
  };

  programs.zoxide.enable = true;

  programs.exa = {
    enable = true;
    # enableAliases = true;
    package = pkgs.unstable.exa;
  };

  # nix-index
  programs.nix-index.enable = true;

  programs.nnn = {
    enable = true;
    package = pkgs.unstable.nnn.override ({ withNerdIcons = true; });
  };

  programs.htop.enable = true;

  programs.bat.enable = true;

  home.packages = with pkgs; [
    # tools that don't have home-manager modules
    ripgrep
    fd
    file
    lsof
    killall
  ];
}
