{ flake-inputs, ... }:
let
  mkNixpkgsOverlay = { attrName, over, extraImportArgs ? { } }:
    final: prev: {
      ${attrName} = import over ({
        system = final.system;
        config.allowUnfree = true;
      } // extraImportArgs);
    };
  nixos-unstable-overlay = mkNixpkgsOverlay {
    attrName = "unstable";
    over = flake-inputs.nixpkgs-unstable;
    extraImportArgs = { overlays = [ flake-inputs.emacs-overlay.overlay ]; };
  };
  nixpkgs-master-overlay = mkNixpkgsOverlay {
    attrName = "master";
    over = flake-inputs.nixpkgs-master;
  };
  nixpkgs-local-overlay = mkNixpkgsOverlay {
    attrName = "local";
    over = flake-inputs.nixpkgs-local;
  };
in {
  # add overlays for the different nixpkgs-versions
  nixpkgs.overlays =
    [ nixos-unstable-overlay nixpkgs-master-overlay nixpkgs-local-overlay ];

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
