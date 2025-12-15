# NOTE: NEEDS NIRI AS A PACKAGE THROUGH REGULAR NIXOS
{
  config,
  pkgs,
  # flake-inputs,
  # thisFlakePath,
  ...
}:
let
  # swaylock but with fancy background-blurring effect
  swaylockPkg = pkgs.swaylock-effects;
in
{
  xdg = {
    enable = true;

    configFile."niri".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/niri/";

    configFile."waybar".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dotfiles/waybar/";

    # configFile."waybar".source = flake-inputs.waybar-WaybarTheme;
  };

  home.packages =
    with pkgs;
    [
      playerctl
      rofi
      brightnessctl
      xwayland-satellite
      wlogout
      networkmanagerapplet

      # wallpaper stuff
      mpvpaper
      waypaper

      # `blueman` installed through `services.blueman.enable`
    ]
    ++ [ swaylockPkg ];

  programs.waybar = {
    enable = true;

    systemd = {
      enable = true;
    };
  };

  # based on  https://yalter.github.io/niri/Example-systemd-Setup.html
  services.swayidle =
    let
      swaylockCmd = "${swaylockPkg}/bin/swaylock --screenshot --effect-blur 4x4 --show-failed-attempts --show-keyboard-layout --ignore-empty-password --daemonize";
    in
    {
      enable = true;

      timeouts = [
        {
          timeout = 600;
          command = "${swaylockCmd}";
        }
        {
          timeout = 601;
          command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
        }
      ];

      events = {
        "before-sleep" = "${swaylockCmd}";
      };
    };

  # somewhat buggy with non-hyprland DE, i.e., gnome
  # home.packages = [ pkgs.wl-clipboard ];
}
