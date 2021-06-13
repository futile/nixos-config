# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  # Enable flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes ca-references
    '';
  };

  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = true;

  # enable REISUB etc.: https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
  boot.kernel.sysctl = {
    "kernel.sysrq" = 1;
  };

  # enable booting into a crashDump kernel when my system panics/hangs
  boot.crashDump.enable = true;

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

    # I have an nvidia card. virtualbox-guest runs mkOverride 50, so we do too.
    videoDrivers = lib.mkOverride 50 [ "nvidia" ];

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
  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;

    # from https://nixos.wiki/wiki/PulseAudio
    package = pkgs.pulseaudioFull;
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
    # gnomeExtensions.topicons-plus # package broken
    nordic-polar
    # ccache # not sure if I want this as a system package, maybe for convenient `ccache -s`?

    # Would like this to be in home.nix, but not in home-manager/20.09 :(
    nix-index

    # monitoring
    lm_sensors
    nvtop
  ];

  programs.fish.enable = true;

  services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];
  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
    extraOptions = "--config-file=${
        pkgs.writeText "daemon.json" ''{
            "ipv6": true,
            "fixed-cidr-v6":"fd00::/80"
          }''
      }";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

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

