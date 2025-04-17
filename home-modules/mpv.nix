{ config, pkgs, ... }: {
  home.packages = with pkgs; [
    mpv
  ];

  xdg = {
    enable = true;
    configFile."mpv".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos/dotfiles/mpv/";
  };
}
