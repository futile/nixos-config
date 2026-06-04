# NOTE: NEEDS NIRI AS A PACKAGE THROUGH REGULAR NIXOS
{
  config,
  pkgs,
  # flake-inputs,
  thisFlakePath,
  ...
}:
let
  # swaylock but with fancy background-blurring effect
  swaylockPkg = pkgs.swaylock-effects;
  sudoAskpassPkg = pkgs.lxqt.lxqt-openssh-askpass;
  noctaliaLockBeforeSleep = "${thisFlakePath}/bin/noctalia-lock-before-sleep";
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

    SUDO_ASKPASS = "${sudoAskpassPkg}/bin/lxqt-openssh-askpass";
  };

  # based on  https://yalter.github.io/niri/Example-systemd-Setup.html
  services.swayidle =
    let
      swaylockCmd = "${swaylockPkg}/bin/swaylock --screenshot --effect-blur 4x4 --show-failed-attempts --show-keyboard-layout --ignore-empty-password --daemonize";
    in
    {
      # turned off for noctalia-shell
      enable = false;

      timeouts = [
        {
          timeout = 3 * 600;
          command = "${swaylockCmd}";
        }
        {
          timeout = 601;
          command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
        }
      ];

      events = {
        "before-sleep" = "${swaylockCmd}";
        "lock" = "${swaylockCmd}";
      };
    };

  systemd.user.services.noctalia-lock-before-sleep = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Lock Noctalia before system sleep";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=sleep --mode=delay --who=noctalia-lock-before-sleep --why='Lock Noctalia before sleep' ${pkgs.bash}/bin/bash ${noctaliaLockBeforeSleep} --wait-once";
      Restart = "always";
      RestartSec = "10s";
      Environment = "PATH=${
        pkgs.lib.makeBinPath [
          pkgs.systemd
          pkgs.gawk
        ]
      }:/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
