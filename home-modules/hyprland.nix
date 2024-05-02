{ config, pkgs, flake-inputs, thisFlakePath, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = "source = ~/.config/hypr/local.conf";
  };

  programs.eww = {
    enable = true;
    configDir = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/eww";
  };

  # somewhat buggy with non-hyprland DE, i.e., gnome
  # home.packages = [ pkgs.wl-clipboard ];
}
