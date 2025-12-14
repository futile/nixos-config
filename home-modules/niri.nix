# NOTE: NEEDS NIRI AS A PACKAGE THROUGH REGULAR NIXOS
{
  config,
  pkgs,
  flake-inputs,
  thisFlakePath,
  ...
}:
{
  xdg = {
    enable = true;
    configFile."niri".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/niri/";
  };

  home.packages = with pkgs; [
    playerctl
    rofi
    swaylock
    brightnessctl
    xwayland-satellite
  ];

  programs.waybar = {
    enable = true;

    systemd = {
      enable = true;
    };
  };

  # somewhat buggy with non-hyprland DE, i.e., gnome
  # home.packages = [ pkgs.wl-clipboard ];
}
