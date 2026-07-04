# NOTE: NEEDS NIRI AS A PACKAGE THROUGH REGULAR NIXOS
{
  config,
  pkgs,
  # flake-inputs,
  ...
}:
let
  # swaylock but with fancy background-blurring effect
  swaylockPkg = pkgs.swaylock-effects;
  sudoAskpassPkg = pkgs.lxqt.lxqt-openssh-askpass;
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
      brightnessctl
      xwayland-satellite
      wlogout
      wl-clipboard
      networkmanagerapplet
      sudoAskpassPkg

      # wallpaper stuff
      mpvpaper
      waypaper

      # `blueman` installed through `services.blueman.enable`
    ]
    ++ [ swaylockPkg ];

  programs.rofi = {
    enable = true;
    plugins = with pkgs; [
      rofi-games
    ];
  };

  programs.waybar = {
    # disabled for noctalia-shell
    enable = false;

    systemd = {
      enable = true;
    };
  };

  home.sessionVariables = {
    # for discord etc.
    NIXOS_OZONE_WL = "1";

    # fix Tiled, Mgba, and other QT apps.
    # 2026-07-04 need to apply this to individual apps or things go awry.
    # QT_QPA_PLATFORM = "xcb";

    SUDO_ASKPASS = "${sudoAskpassPkg}/bin/lxqt-openssh-askpass";
  };

  services.swayidle = {
    enable = true;

    timeouts = [ ];

    events = {
      "before-sleep" = "/run/current-system/sw/bin/noctalia msg session lock";
    };
  };
}
