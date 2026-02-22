{
  config,
  pkgs,
  lib,
  flake-inputs,
  ...
}:

let
  flakeRoot = flake-inputs.self.outPath;
in
{
  imports =
    let
      modules = "${flakeRoot}/modules";
    in
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # nixos-hardware module
      flake-inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen3

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

      # ausweisapp
      "${modules}/ausweisapp.nix"

      # geoclue2; location provider for gammastep
      # 2026-12-15: couldn't get this to work :(
      "${modules}/geoclue2.nix"

      # user-configuration with home-manager
      "${modules}/home-manager.nix"

      # give me steam
      "${modules}/steam.nix"

      # hyprland
      # flake-inputs.hyprland.nixosModules.default
    ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.felix = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "wireshark"
    ];
    shell = pkgs.fish;
  };

  # Shell must also be in `/etc/shells` or it might not work
  # should be there by default, if we don't use one from another flake-input etc.
  # environment.shells = [ "${pkgs.unstable.fish}/bin/fish" ];

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

  networking = {
    hostId = "3168bba2"; # Just a unique ID (for ZFS)
    hostName = "nixos-work"; # Define your hostname.

    networkmanager = {
      enable = true;
    };

    # enable once networkmanager is updated (& whole system)
    # wireless.enable = true; # Enables wireless support via wpa_supplicant.
  };

  time = {
    # Set your time zone.
    timeZone = "Europe/Berlin";
    # timeZone = "Asia/Bangkok";

    # For dualbooting with Windows
    hardwareClockInLocalTime = true;
  };

  boot = {
    # Use the systemd-boot EFI boot loader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # ZFS unlock at boot time
    zfs.requestEncryptionCredentials = true;

    # 2025-12-24 USB wifi stick "Archer TX10UB Nano" requires at least this kernel for wifi to work
    # 2026-01-05 That wifi stick isn't working anyway, even with 6.17, but let's try 6.18 -> no zfs yet
    # 2026-01-30 6.18 still no zfs
    kernelPackages = pkgs.linuxPackages_6_18;
  };

  i18n.inputMethod = {
    type = "ibus";
  };

  services = {
    # 2024-10-01 `latestCompatibleLinuxPackages` was deprecated, need to hardcode now..
    # boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    # ... but 6.11 broken with zfs for now (:
    # boot.kernelPackages = pkgs.linuxPackages_latest;

    fwupd.enable = true;

    # Enable the X11 windowing system.
    xserver = {
      enable = true;

      # fast(er) key repeat
      # seem not to work!
      autoRepeatDelay = 190;
      autoRepeatInterval = 30;
    };

    displayManager = {
      # Enable gdm & GNOME 3 Desktop Environment.
      gdm = {
        enable = true;
        wayland = true;
      };

      # disabling this for now, not using it anyway.
      # windowManager.qtile.enable = true;

      # because we have encrypted ZFS, and thus already enter a password during boot
      autoLogin = {
        # disabled because I think it broke my graphical session, see https://github.com/NixOS/nixpkgs/issues/103746
        # 2025-10-19: testing enabling, should be fixed: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-3419081665
        enable = true;
        user = "felix";
      };
    };

    desktopManager = {
      gnome = {
        enable = true;
        extraGSettingsOverridePackages = [ pkgs.mutter ];
        extraGSettingsOverrides = ''
          [org.gnome.mutter]
          experimental-features = ['scale-monitor-framebuffer']
        '';
      };
    };

    # Enable touchpad support (enabled default in most desktopManager).
    libinput.enable = true;

    udev.packages = with pkgs; [ gnome-settings-daemon ];

    blueman.enable = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    pkgs.fish # for the same reason it's also in `environment.shells`

    wget
    bash
    vim-full
    coreutils
    git
    rsync
    dconf-editor
    adwaita-icon-theme

    # how to declaratively configure dconf/gnome extensions:
    # https://github.com/willmcpherson2/willos/blob/a6fe74f71886c18a08de16a348e66b08f4e0debf/will/home.nix#L206-L225

    gnomeExtensions.appindicator
    gnomeExtensions.pop-shell
    #    gnomeExtensions.pop-launcher-super-key
    gnomeExtensions.vitals
    # gnomeExtensions.topicons-plus # package broken
    # hot corners in other corners than top-left (to mimic macos better)
    gnomeExtensions.custom-hot-corners-extended

    nordic

    # monitoring
    lm_sensors
    cachix # just use cachix system-wide

    # vpn stuff
    openvpn
    networkmanager-openvpn
  ];

  programs = {
    # we like our fish-shell
    fish.enable = true;

    # Enable hyprland
    # programs.hyprland.enable = true;

    # Enable niri
    niri.enable = true;

    # NOTE: required for `--allow-other` with rclone, see `home-modules/desktop-gdrive-keepassxc.nix`
    fuse.userAllowOther = true;

    wireshark = {
      enable = true;
      dumpcap.enable = true;
      usbmon.enable = true;
    };

    ccache = {
      enable = true;
      packageNames = [
        "linux" # build our kernel with ccache, as we have crashdump enabled, which requires compiling it ourselves
      ];
    };
  };

  # Since we run docker on an zfs partition
  virtualisation.docker.storageDriver = "zfs";

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
  # networking.firewall.allowedTCPPorts = [ 8080 ]; # this worked :)
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
