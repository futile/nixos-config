{ ... }: {
  # Keep a maximum of 10 generations, so our /boot partition doesn't run full
  boot.loader.systemd-boot.configurationLimit = 10;

  # Enable NTFS support
  boot.supportedFilesystems = [ "ntfs" ];

  # enable REISUB etc.: https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
  boot.kernel.sysctl = { "kernel.sysrq" = 1; };

  # Select internationalisation properties; en-US by default
  i18n.defaultLocale = "en_US.UTF-8";

  # Default console font
  console.font = "Lat2-Terminus16";
}
