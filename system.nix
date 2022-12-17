# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  # Enable flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    settings = {
      trusted-users = [ "felix" ];

      # add paths to the nix sandbox
      extra-sandbox-paths = [
        # ccache needs to be available in the sandbox
        config.programs.ccache.cacheDir
      ];
    };
  };

  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep a maximum of 10 generations, so our /boot partition doesn't run full
  boot.loader.systemd-boot.configurationLimit = 10;

  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = true;

  # enable REISUB etc.: https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
  boot.kernel.sysctl = { "kernel.sysrq" = 1; };

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

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

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

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "neo";
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

    # try virtualbox driver first, then fall back to nvidia.
    videoDrivers = [ "virtualbox" "nvidia" "nouveau" ];

    # Enable gdm & GNOME 3 Desktop Environment.
    displayManager.gdm = {
      enable = true;
      # We don't want wayland for now; e.g. screensharing doesn't work (well)
      wayland = false;
      # When we want wayland, we also want to run with nvidia.
      # This requires some other options (`nixos-rebuild` will tell us which),
      # so disable for now.
      # nvidiaWayland = true;
    };
    desktopManager.gnome.enable = true;
    windowManager.qtile.enable = true;

    # Configure keymap in X11
    layout = "de,de";
    xkbVariant = "neo,basic";
    # xkbOptions = "grp:menu_toggle"; # 'menu_toggle' -> context-menu key

    # Enable touchpad support (enabled default in most desktopManager).
    # libinput.enable = true;
  };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # Mostly from https://discourse.nixos.org/t/headphone-volume-resets-itself-to-100/13866/2
  sound.enable = false;
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
    shell = pkgs.fish;
  };

  # ZFS services
  services.zfs.autoScrub.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
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

  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
    # enable ipv6 support inside docker
    daemon.settings = {
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
    };
  };

  virtualisation.virtualbox = {
    host.enable = true;
    host.enableExtensionPack = true;
  };

  # enable unprivileged user namespaces (for ccf/env_isolation)
  # probably not necessary, as this should only be relevant for a hardened kernel (otherwise enabled by default)
  security.unprivilegedUsernsClone = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

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

