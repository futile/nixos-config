{ config, pkgs, lib, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # base/common system config
    ./modules/system-base.nix

    # docker
    ./modules/docker.nix
  ];

  nix.settings.trusted-users = [ "felix" ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS support (& NTFS)
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = true;

  # enable booting into a crashDump kernel when my system panics/hangs
  # this causes recompilation, don't want/need it currently
  # boot.crashDump.enable = true;

  # more up-to-date kernel: `linuxPackages_latest`; for testing
  # ccf/env_isolation I want at least 5.11 for overlayfs in user namespaces;
  # this gives me 5.14 (at the time of writing).
  #
  # Need to hardcode the version for now, as otherwise zfs might no be
  # available.  From NixOS 21.11 onwards I can use
  # `config.boot.zfs.package.latestCompatibleLinuxPackages` it seems.
  # https://discourse.nixos.org/t/package-zfs-kernel-2-0-6-5-15-2-in-is-marked-as-broken-refusing-to-evaluate/16168/3
  # boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages; # pkgs.linuxPackages_5_15;
  # boot.kernelPackages = pkgs.linuxPackages_5_15; # virtualbox broken on current kernel >=5.17 :( https://github.com/NixOS/nixpkgs/commit/69af0d17174ee60f75e6e9f4d74c2152f4e7968e
  # TODO 22.05: Do I still want another kernel version?
  # Yeah let's, also need it for lenovo-p14s laptop, so why not? :)
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  # A ZFS version compatible with my kernel version.
  # boot.zfs.enableUnstable = true;

  networking.hostId = "6adc5431"; # Just a unique ID (for ZFS)
  networking.hostName = "nixos-home"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  time = {
    # Set your time zone.
    timeZone = "Europe/Berlin";
    # For dualbooting with Windows
    hardwareClockInLocalTime = true;
  };

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;

  # Interface available when booting in VirtualBox
  networking.interfaces.enp0s3.useDHCP = true;
  systemd.units."sys-subsystem-net-devices-enp0s3.device".text = ''
    [Unit]
    ConditionVirtualization=oracle
  '';

  # Interface available when booting natively 
  networking.interfaces.eno1.useDHCP = true;
  systemd.units."sys-subsystem-net-devices-eno1.device".text = ''
    [Unit]
    ConditionVirtualization=none
  '';

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # console keymap
  console.keyMap = "neo";

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

    # nvidia let's go
    videoDrivers = [ "nvidia" "nouveau" ];

    # Enable gdm & GNOME 3 Desktop Environment.
    displayManager = {
      # because we have encrypted ZFS, and thus already enter a password during boot
      autoLogin = {
        enable =
          false; # disabled because I think it broke my graphical session, see https://github.com/NixOS/nixpkgs/issues/103746
        user = "felix";
      };

      gdm = {
        enable = true;
        # We don't want wayland for now; e.g. screensharing doesn't work (well)
        wayland = false;
        # When we want wayland, we also want to run with nvidia.
        # This requires some other options (`nixos-rebuild` will tell us which),
        # so disable for now.
        # nvidiaWayland = true;
      };
    };
    desktopManager.gnome.enable = true;

    # disabling this for now, not using it anyway.
    # windowManager.qtile.enable = true;

    # Configure keymap in X11
    layout = "de,de";
    xkbVariant = "neo,basic";
    # xkbOptions = "grp:menu_toggle"; # 'menu_toggle' -> context-menu key

    # fast(er) key repeat
    # seem not to work!
    autoRepeatDelay = 190;
    autoRepeatInterval = 30;

    # Enable touchpad support (enabled default in most desktopManager).
    # libinput.enable = true;
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # Mostly from https://discourse.nixos.org/t/headphone-volume-resets-itself-to-100/13866/2
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.felix = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.unstable.fish;
  };

  # Shell must also be in `/etc/shells` or it might not work
  environment.shells = [ "${pkgs.unstable.fish}/bin/fish" ];

  # ZFS services
  services.zfs.autoScrub.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    pkgs.unstable.fish # for the same reason it's also in `environment.shells`

    wget
    bash
    vimHugeX
    coreutils
    git
    rsync
    gnome3.dconf-editor
    gnome3.adwaita-icon-theme
    gnomeExtensions.appindicator
    gnomeExtensions.pop-shell
    gnomeExtensions.pop-launcher-super-key
    gnomeExtensions.vitals
    # gnomeExtensions.topicons-plus # package broken
    nordic
    # ccache # not sure if I want this as a system package, maybe for convenient `ccache -s`?

    # monitoring
    lm_sensors
    nvtop
    cachix # just use cachix system-wide

    # vpn stuff
    openvpn
    gnome.networkmanager-openvpn
  ];

  services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

  virtualisation.docker.storageDriver = "zfs";

  # virtualisation.virtualbox = {
  #   host.enable = true;
  # cause too much rebuilding, also prevent using a newer kernel I think
  # host.enableExtensionPack = true;
  # };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Keeping this for reference
  # programs.fuse.userAllowOther = true;

  programs.fish.enable = true;
  programs.ccache = {
    enable = true;
    packageNames = [
      "linux" # build our kernel with ccache, as we have crashdump enabled, which requires compiling it ourselves
    ];
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?

}

