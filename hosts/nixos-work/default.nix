{ config, pkgs, lib, flake-inputs, ... }:

let flakeRoot = flake-inputs.self.outPath;
in {
  imports =
    let modules = "${flakeRoot}/modules";
    in [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # nixos-hardware module
      flake-inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen2

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

      # hyprland
      flake-inputs.hyprland.nixosModules.default
    ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.felix = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
  };

  # Shell must also be in `/etc/shells` or it might not work
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

  # we like our fish-shell
  programs.fish.enable = true;

  networking.hostId = "3168bba2"; # Just a unique ID (for ZFS)
  networking.hostName = "nixos-work"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  time = {
    # Set your time zone.
    # timeZone = "Europe/Berlin";
    timeZone = "Asia/Bangkok";

    # For dualbooting with Windows
    hardwareClockInLocalTime = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS unlock at boot time
  boot.zfs.requestEncryptionCredentials = true;

  # just for fun, don't think I need this
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

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
        wayland = true;
      };
    };

    desktopManager.gnome = {
      enable = true;
      extraGSettingsOverridePackages = [ pkgs.gnome.mutter ];
      extraGSettingsOverrides = ''
        [org.gnome.mutter]
        experimental-features = ['scale-monitor-framebuffer']
      '';
    };

    # disabling this for now, not using it anyway.
    # windowManager.qtile.enable = true;

    # fast(er) key repeat
    # seem not to work!
    autoRepeatDelay = 190;
    autoRepeatInterval = 30;

    # Enable touchpad support (enabled default in most desktopManager).
    libinput.enable = true;
  };

  # also enable hyprand
  programs.hyprland.enable = true;

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

    # monitoring
    lm_sensors
    cachix # just use cachix system-wide

    # vpn stuff
    openvpn
    gnome.networkmanager-openvpn
  ];

  services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

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
  system.stateVersion = "23.05"; # Did you read the comment?
}
