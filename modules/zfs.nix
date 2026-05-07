{
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.supportedFilesystems = [ "zfs" ];

  # 2026-05-08 evaluation warning: `boot.zfs.forceImportRoot` is using the
  # default value of `true`. It is highly recommended to set it to `false`, the
  # new default from 26.11 on, to reduce the risk of data loss.
  boot.zfs.forceImportRoot = false;

  # For a more recent ZFS version
  # boot.zfs.enableUnstable = true;

  # Enable auto-scrubbing
  services.zfs.autoScrub.enable = true;
}
