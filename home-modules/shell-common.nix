{ config, lib, pkgs, thisFlakePath, ... }:

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

  programs.zoxide = {
    enable = true;
    package = pkgs.unstable.zoxide;
  };

  programs.eza = {
    enable = true;
    # enableAliases = true;
    package = pkgs.unstable.eza;
  };

  # nix-index
  programs.nix-index.enable = true;

  programs.nnn = {
    enable = true;
    package = pkgs.unstable.nnn.override ({ withNerdIcons = true; });
  };

  programs.htop.enable = true;

  # the better htop
  programs.btop = {
    enable = true;
    package = pkgs.unstable.btop;
  };

  # bat + config
  programs.bat.enable = true;
  xdg = {
    enable = true;

    # symlink directly to this repo, for easier iteration/changes
    configFile."bat/config".source =
      config.lib.file.mkOutOfStoreSymlink
        "${thisFlakePath}/dotfiles/bat/config";
  };

  home.packages = with pkgs;
    [
      # tools that don't have home-manager modules
      ripgrep
      fd
      file
      lsof
      killall
    ];
}
