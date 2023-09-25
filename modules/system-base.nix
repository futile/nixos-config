{ pkgs, ... }: {
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

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # These two settings (try to) increase `ulimit -Sn`, aka max number of open fd's per process (thread?).
  # Not even sure I want this, while it might make stuff work more out-of-the-box for me, it might hide
  # problems other people run into from me. Also, `ulimit -Sn` can be run without sudo, as long as the 
  # hard limit, i.e., `ulimit -Hn`, is high enough (this requires root to change).
  # But maybe once I have it in my config I will actually remember it, and maybe think of it when other
  # people run into problems I don't run into.
  # -- Yeah, let's not do it for now, hopefully this way I'll keep it in mind anyway :)

  # increase limit of open files, aka `ulimit -Sn`.
  # needed this for `vite` with lots of files.
  # ref https://stackoverflow.com/questions/70473410/how-do-i-increase-the-limit-on-the-number-of-open-files-in-nixos
  # ref https://vitejs.dev/guide/troubleshooting.html#requests-are-stalled-forever
  # security.pam.loginLimits = [{
  #   domain = "*";
  #   type = "soft";
  #   item = "nofile";
  #   value = "8192";
  # }];

  # grmlgrmlgrml, systemd needs some extra poking it seems.
  # https://github.com/NixOS/nixpkgs/issues/159964#issuecomment-1477971458
  # systemd.user.extraConfig = "DefaultLimitNOFILE=8192";
}
