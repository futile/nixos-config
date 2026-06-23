{
  flake-inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  mkNixpkgsOverlay =
    {
      attrName,
      over,
      extraImportArgs ? { },
    }:
    final: prev: {
      ${attrName} = import over (
        {
          system = final.system;
          config.allowUnfree = true;
        }
        // extraImportArgs
      );
    };
  # nixos-unstable-overlay = mkNixpkgsOverlay
  #   {
  #     attrName = "unstable";
  #     over = flake-inputs.nixpkgs-unstable;
  #     extraImportArgs = { overlays = [ flake-inputs.emacs-overlay.overlay ]; };
  #   };
  nixpkgs-unstable-overlay = mkNixpkgsOverlay {
    attrName = "nixpkgs-unstable";
    over = flake-inputs.nixpkgs-pkgs-unstable;
  };
  # nixpkgs-master-overlay = mkNixpkgsOverlay
  #   {
  #     attrName = "master";
  #     over = flake-inputs.nixpkgs-master;
  #   };
  # nixpkgs-local-overlay = mkNixpkgsOverlay
  #   {
  #     attrName = "local";
  #     over = flake-inputs.nixpkgs-local;
  #   };
  custom-packages-overlay = final: prev: {
    my-custom-packages = {
      agent-safehouse = final.callPackage ../custom-packages/agent-safehouse.nix { };
      context-mode = final.callPackage ../custom-packages/context-mode.nix { };
      gascity = final.callPackage ../custom-packages/gascity.nix { };
      headroom = final.callPackage ../custom-packages/headroom.nix { };
      llm-wiki = final.callPackage ../custom-packages/llm-wiki.nix { };
      marker = final.callPackage ../custom-packages/marker.nix { };
      mex = final.callPackage ../custom-packages/mex.nix { };
      phinger-cursors-extended = final.callPackage ../custom-packages/phinger-cursors-extended.nix { };
      serena = final.callPackage ../custom-packages/serena-with-editor-tools.nix {
        serenaInput = flake-inputs.serena;
        editorTools = final.lib.my.editorTools;
      };
      serena-custom = final.callPackage ../custom-packages/serena-custom.nix { };
    };
  };
in
{
  options.my.permittedInsecurePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Mergeable list of insecure nixpkgs package names allowed for this configuration.

      This option exists because `nixpkgs.config.permittedInsecurePackages` itself is
      part of the `nixpkgs.config` attrset merge, which does not append lists across
      modules. Defining the allowlist here lets shared modules and hosts contribute to
      one combined list, which is then forwarded once into nixpkgs.
    '';
  };

  config = {
    # Allow unfree packages.
    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.permittedInsecurePackages = config.my.permittedInsecurePackages;

    # nix base config
    nix = {
      # for unstable/more recent nix:
      # package = pkgs.nixVersions.latest;

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

    # add overlays for the different nixpkgs-versions
    nixpkgs.overlays = [
      # nixos-unstable-overlay
      nixpkgs-unstable-overlay
      # nixpkgs-master-overlay
      # nixpkgs-local-overlay
      custom-packages-overlay
      # flake-inputs.emacs-overlay.overlay
    ];

    # registry entries
    nix.registry = {
      stable.flake = flake-inputs.nixpkgs;
      osUnstable.flake = flake-inputs.nixpkgs;
      unstable.flake = flake-inputs.nixpkgs-pkgs-unstable;
      # master.flake = flake-inputs.nixpkgs-master;
      # local.flake = flake-inputs.nixpkgs-local;
    };

    # nix path to correspond to my flakes
    nix.nixPath = [
      "nixpkgs=${flake-inputs.nixpkgs}"
      "unstable=${flake-inputs.nixpkgs-pkgs-unstable}"
    ];
  };
}
