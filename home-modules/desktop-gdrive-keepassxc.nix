{ pkgs, ... }:
# google-drive and keepassxc are currently intertwined, so set them up together
{
  home.packages = with pkgs; [ keepassxc rclone ];

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

      Install = { WantedBy = [ "default.target" ]; };
    };

    keepassxc = {
      Unit = {
        Description = "Autostart Keepassxc";
        After =
          [ "graphical-session-pre.target" "rclone-gdrive.service" ];
        Wants = [ "rclone-gdrive.service" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.keepassxc}/bin/keepassxc";
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}
