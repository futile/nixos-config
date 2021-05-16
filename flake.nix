{
  description = "Full Flake Panic!";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-20.09"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-master = { url = "github:nixos/nixpkgs/master"; };

    home-manager = {
      url = "github:nix-community/home-manager/release-20.09";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    fish-foreign-env = {
      url = "github:oh-my-fish/plugin-foreign-env";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-master, home-manager, ...
    }@inputs:
    let
      system = "x86_64-linux";
      mkNixpkgsOverlay = { attrName, over }:
        final: prev: {
          ${attrName} = import over {
            system = final.system;
            config.allowUnfree = true;
          };
        };
      nixos-unstable-overlay = mkNixpkgsOverlay {
        attrName = "unstable";
        over = nixpkgs-unstable;
      };
      nixpkgs-master-overlay = mkNixpkgsOverlay {
        attrName = "master";
        over = nixpkgs-master;
      };
      lib = {
        # reference: https://discourse.nixos.org/t/wrapping-packages/4431
        mkWrappedWithDeps =
          { pkg, prefix-deps, suffix-deps, pathsToWrap, otherArgs ? { } }:
          let
            prefixBinPath = nixpkgs.lib.makeBinPath prefix-deps;
            suffixBinPath = nixpkgs.lib.makeBinPath suffix-deps;
            pkgs = nixpkgs.legacyPackages.${system};
          in pkgs.symlinkJoin ({
            name = pkg.name + "-wrapped";
            paths = [ pkg ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              cd "$out"
              for p in ${builtins.toString pathsToWrap}
              do
                wrapProgram "$out/$p" --prefix PATH : "${prefixBinPath}" --suffix PATH : "${suffixBinPath}"
              done
            '';
          } // otherArgs);
      };
    in rec {
      nixosConfigurations.nixos-home = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # add unstable overlay
          ({
            nixpkgs.overlays =
              [ nixos-unstable-overlay nixpkgs-master-overlay ];
          })

          # load system config
          ./system.nix

          # user config
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.felix =
              import ./home.nix { inherit inputs lib; };
          }
        ];
      };
    };
}
