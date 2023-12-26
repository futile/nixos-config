{ flake-inputs, pkgs, config, ... }:
let
  mkNixpkgsOverlay = { attrName, over, extraImportArgs ? { } }:
    final: prev: {
      ${attrName} = import over ({
        system = final.system;
        config.allowUnfree = true;

        # obsidian 1.4.16 relies on an EOL electron version, so allow it for now.
        # this will make sure that it will fail again if a newer version also relies
        # on the old electron version, so the exemption won't be here forever.
        # see https://github.com/NixOS/nixpkgs/issues/273611#issuecomment-1858755633
        config.permittedInsecurePackages =
          final.lib.optional (final.obsidian.version == "1.4.16") "electron-25.9.0";
      } // extraImportArgs);
    };
  nixos-unstable-overlay = mkNixpkgsOverlay
    {
      attrName = "unstable";
      over = flake-inputs.nixpkgs-unstable;
      extraImportArgs = { overlays = [ flake-inputs.emacs-overlay.overlay ]; };
    };
  nixpkgs-master-overlay = mkNixpkgsOverlay
    {
      attrName = "master";
      over = flake-inputs.nixpkgs-master;
    };
  nixpkgs-local-overlay = mkNixpkgsOverlay
    {
      attrName = "local";
      over = flake-inputs.nixpkgs-local;
    };
  custom-packages-overlay = final: prev: {
    my-custom-packages = {
      phinger-cursors-extended = final.callPackage ../custom-packages/phinger-cursors-extended.nix { };
    };
  };
in
{
  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

  # add overlays for the different nixpkgs-versions
  nixpkgs.overlays =
    [ nixos-unstable-overlay nixpkgs-master-overlay nixpkgs-local-overlay custom-packages-overlay ];

  # nix base config
  nix = {
    # for unstable/more recent nix:
    # package = pkgs.unstable.nix;

    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    settings = {
      # add paths to the nix sandbox
      extra-sandbox-paths = [
        # ccache needs to be available in the sandbox
        config.programs.ccache.cacheDir
      ];
    };
  };

  # registry entries
  nix.registry = {
    stable.flake = flake-inputs.nixpkgs;
    osUnstable.flake = flake-inputs.nixpkgs-unstable;
    unstable.flake = flake-inputs.nixpkgs-pkgs-unstable;
    master.flake = flake-inputs.nixpkgs-master;
    local.flake = flake-inputs.nixpkgs-local;
  };

  # nix path to correspond to my flakes
  nix.nixPath = [
    "nixpkgs=${flake-inputs.nixpkgs}"
    "unstable=${flake-inputs.nixpkgs-unstable}"
  ];
}

