{ config, pkgs, lib, flake-inputs, ... }:

let flakeRoot = flake-inputs.self.outPath;
in {
  imports =
    let modules = "${flakeRoot}/modules";
    in [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # ZFS with common settings
      "${modules}/zfs.nix"

      # base/common system config
      "${modules}/system-base.nix"

      # use pipewire for audio
      "${modules}/audio-pipewire.nix"

      # neo layout
      "${modules}/neo-layout.nix"

      # my fonts
      "${modules}/fonts.nix"

      # docker
      "${modules}/docker.nix"

      # user-configuration with home-manager
      "${modules}/home-manager.nix"
    ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.felix = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
  };

  # Shell must also be in `/etc/shells` or it might not work
  # should be there by default, if we don't use one from another flake-input etc.
  # environment.shells = [ "${pkgs.fish}/bin/fish" ];

  # allow our user to use `nix`
  nix.settings.trusted-users = [ "felix" ];

  # home-manager configuration
  home-manager = {
    # forward system-specific arguments to home-manager
    extraSpecialArgs = {
      # absolute path to this flake, i.e., to break nix's isolation
      thisFlakePath = config.users.users.felix.home + "/nixos";
    };

    # my user config
    users.felix = ./home.nix;
  };

  # get rid of default shell aliases;
  # see also: https://discourse.nixos.org/t/fish-alias-added-by-nixos-cant-delete/19626/3
  environment.shellAliases = lib.mkForce { };

  # we like our fish-shell
  programs.fish.enable = true;

  networking.hostId = "6adc5431"; # Just a unique ID (for ZFS)
  networking.hostName = "nixos-home"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  time = {
    # Set your time zone.
    timeZone = "Europe/Berlin";
    # For dualbooting with Windows
    hardwareClockInLocalTime = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS unlock at boot time
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

  # NOTE: workaround to prevent auto-login from crashing, see https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

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
          true; # needs the workaround from above to not break my graphical session, see https://github.com/NixOS/nixpkgs/issues/103746
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

      # try 34679 at making auto key repeat work..
      sessionCommands = ''
        xset r rate 150 30
      '';
    };

    desktopManager.gnome.enable = true;

    # disabling this for now, not using it anyway.
    # windowManager.qtile.enable = true;

    # fast(er) key repeat
    # seem not to work!
    # See `nixos-home` for an x11-alternative using a systemd service to run `xset`.
    # autoRepeatDelay = 150;
    # autoRepeatInterval = 30;

    # Enable touchpad support (enabled default in most desktopManager).
    # libinput.enable = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    pkgs.fish # for the same reason it's also in `environment.shells`

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

    # monitoring
    lm_sensors
    nvtop
    cachix # just use cachix system-wide

    # vpn stuff
    openvpn
    gnome.networkmanager-openvpn
  ];

  services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

  # enable opentabletdriver (for osu-lazer); see https://opentabletdriver.net/Wiki/Install/Linux#nixos
  hardware.opentabletdriver.enable = true;

  # Since we run docker on an zfs partition
  virtualisation.docker.storageDriver = "zfs";

  programs.ccache = {
    enable = true;
    packageNames = [
      "linux" # build our kernel with ccache, as we have crashdump enabled, which requires compiling it ourselves
    ];
  };

  # Top-level stuff I keep around for reference:

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

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
