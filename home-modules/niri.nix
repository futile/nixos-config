# NOTE: NEEDS NIRI AS A PACKAGE THROUGH REGULAR NIXOS
{
  config,
  pkgs,
  # flake-inputs,
  # thisFlakePath,
  ...
}:
{
  xdg = {
    enable = true;

    configFile."niri".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/niri/";

    configFile."waybar".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/waybar/";

    # configFile."waybar".source = flake-inputs.waybar-WaybarTheme;
  };

  home.packages = with pkgs; [
    playerctl
    rofi
    swaylock
    brightnessctl
    xwayland-satellite
    wlogout
    networkmanagerapplet

    # `blueman` installed through `services.blueman.enable`
  ];

  programs.waybar = {
    enable = true;

    systemd = {
      enable = true;
    };
  };

  # based on  https://yalter.github.io/niri/Example-systemd-Setup.html
  services.swayidle = {
    enable = true;

    timeouts = [
      {
        timeout = 600;
        command = "${pkgs.swaylock}/bin/swaylock --daemonize --show-failed-attempts --show-keyboard-layout";
      }
      {
        timeout = 601;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
    ];

    events = {
      "before-sleep" =
        "${pkgs.swaylock}/bin/swaylock --daemonize --show-failed-attempts --show-keyboard-layout";
    };
  };

  # somewhat buggy with non-hyprland DE, i.e., gnome
  # home.packages = [ pkgs.wl-clipboard ];
}
