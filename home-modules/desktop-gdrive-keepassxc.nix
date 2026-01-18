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
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    keepassxc = {
      Unit = {
        Description = "Autostart Keepassxc";
        After = [
          "graphical-session-pre.target"
          "rclone-gdrive.service"
        ];
        Wants = [ "rclone-gdrive.service" ];
      };

      Service = {
        Type = "simple";
        # `-platform xcb` for AutoType under Wayland
        # see file:////nix/store/n30lpan6vlwyhjhwa1xs5ggf7ans0fyn-keepassxc-2.7.11/share/keepassxc/docs/KeePassXC_UserGuide.html#_auto_type
        ExecStart = "${pkgs.keepassxc}/bin/keepassxc -platform xcb";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
