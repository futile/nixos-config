{ config, pkgs, flake-inputs, thisFlakePath, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = "source = ~/.config/hypr/local.conf";

    # sets `NIXOS_OZONE_WL` at the time of writing (maybe more in the future :))
    recommendedEnvironment = true;
  };

  programs.eww = {
    enable = true;
    package = pkgs.eww-wayland;
    configDir = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/eww";
  };

  home.packages = [ pkgs.wl-clipboard ];
}
