{ pkgs, ... }:
# google-drive and keepassxc are currently intertwined, so set them up together
{
  home.packages = with pkgs; [
    keepassxc
    rclone
  ];

  # NOTE: requires a normal module, here for documentation!
  # required for `--allow-other` with rclone, see below
  # programs.fuse.userAllowOther = true;

  systemd.user.services = {
    # also based on https://thunderysteak.github.io/rclone-mount-onedrive
    rclone-gdrive = {
      Unit = {
        Description = "Automount google drive";
        After = "network-online.target";
      };

      Service = {
        Type = "simple";
        ExecStart =
          # `--allow-other` because service doesn't properly run as my user while booting/something about graphical DE..
          "${pkgs.rclone}/bin/rclone mount --allow-other --vfs-cache-mode=full gdrive: %h/GoogleDrive";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # adapted from looking at waybar's config using `isd`
    keepassxc = {
      Unit = {
        Description = "Autostart Keepassxc";
        Requires = [ "tray.target" ];
        After = [
          "graphical-session.target"
          "rclone-gdrive.service"
          "tray.target"
        ];
        Wants = [ "rclone-gdrive.service" ];
        PartOf = [
          "graphical-session.target"
          # "tray.target"
        ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Service = {
        Type = "simple";
        # `-platform xcb` for AutoType under Wayland
        # see file:////nix/store/n30lpan6vlwyhjhwa1xs5ggf7ans0fyn-keepassxc-2.7.11/share/keepassxc/docs/KeePassXC_UserGuide.html#_auto_type
        ExecStart = "${pkgs.keepassxc}/bin/keepassxc -platform xcb";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      Install = {
        WantedBy = [
          "graphical-session.target"
          # "tray.target"
        ];
      };
    };
  };
}
