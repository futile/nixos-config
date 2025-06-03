{
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.supportedFilesystems = [ "zfs" ];

  # For a more recent ZFS version
  # boot.zfs.enableUnstable = true;

  # Enable auto-scrubbing
  services.zfs.autoScrub.enable = true;
}
