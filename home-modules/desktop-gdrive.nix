{ pkgs, ... }:
{
  home.packages = with pkgs; [
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
  };
}
