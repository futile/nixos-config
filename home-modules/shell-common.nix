{
  config,
  pkgs,
  thisFlakePath,
  ...
}:

{
  # direnv & nix-direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # can't just symlink it, because `nix-direnv` also writes to it.
    stdlib = "source ${thisFlakePath}/dotfiles/direnv/direnvrc.sh";
  };

  programs.fzf = {
    enable = true;

    # use this custom command to ignore hidden and ignored files by default.
    # also follow symlinks, and '$dir' in fish allows prefixes such as `/var/<ctrl-t>` to work.
    fileWidgetCommand = "fd --type f --follow . \\$dir";
  };

  programs.zoxide = {
    enable = true;
  };

  programs.eza = {
    enable = true;
    # enableAliases = true;
  };

  # nix-index
  programs.nix-index.enable = true;

  # nnn; some file explorer I never used, now prefer `yazi`
  # programs.nnn = {
  #   enable = false;
  #   package = pkgs.nnn.override ({ withNerdIcons = true; });
  # };

  programs.htop.enable = true;

  # the better htop
  programs.btop = {
    enable = true;
  };

  # bat + config
  programs.bat.enable = true;
  xdg = {
    enable = true;

    # symlink directly to this repo, for easier iteration/changes
    configFile."bat/config".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/bat/config";
  };

  home.packages = with pkgs; [
    # tools that don't have home-manager modules
    ripgrep
    fd
    file
    lsof
    killall
  ];
}
