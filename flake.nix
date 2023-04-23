{
  description = "Full Flake Panic!";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-22.11"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-pkgs-unstable = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };
    nixpkgs-master = { url = "github:nixos/nixpkgs/master"; };

    nixpkgs-local = { url = "/home/felix/gits/nixpkgs"; };

    # for emacsGcc; see https://gist.github.com/mjlbach/179cf58e1b6f5afcb9a99d4aaf54f549
    emacs-overlay = { url = "github:nix-community/emacs-overlay"; };

    home-manager = {
      url = "github:nix-community/home-manager/release-22.11";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    fish-foreign-env = {
      url = "github:oh-my-fish/plugin-foreign-env";
      flake = false;
    };

    fish-puffer-fish = {
      url = "github:nickeb96/puffer-fish";
      flake = false;
    };

    fish-tide = {
      url = "github:IlanCosman/tide";
      flake = false;
    };

    doom-emacs = {
      url = "github:hlissner/doom-emacs";
      flake = false;
    };

    wezterm-everforest = {
      url = "git+https://git.sr.ht/~maksim/wezterm-everforest";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-unstable
    , nixpkgs-master
    , home-manager
    , emacs-overlay
    , ...
    }@inputs:
    let
      system = "x86_64-linux";
      mkNixpkgsOverlay = { attrName, over, extraImportArgs ? { } }:
        final: prev: {
          ${attrName} = import over ({
            system = final.system;
            config.allowUnfree = true;
          } // extraImportArgs);
        };
      nixos-unstable-overlay = mkNixpkgsOverlay {
        attrName = "unstable";
        over = nixpkgs-unstable;
        extraImportArgs = { overlays = [ emacs-overlay.overlay ]; };
      };
      nixpkgs-master-overlay = mkNixpkgsOverlay {
        attrName = "master";
        over = nixpkgs-master;
      };
      nixpkgs-local-overlay = mkNixpkgsOverlay {
        attrName = "local";
        over = inputs.nixpkgs-local;
      };
      lib = {
        # reference: https://discourse.nixos.org/t/wrapping-packages/4431
        mkWrappedWithDeps =
          { pkg
          , pathsToWrap
          , prefix-deps ? [ ]
          , suffix-deps ? [ ]
          , extraWrapProgramArgs ? [ ]
          , otherArgs ? { }
          }:
          let
            prefixBinPath = nixpkgs.lib.makeBinPath prefix-deps;
            suffixBinPath = nixpkgs.lib.makeBinPath suffix-deps;
            pkgs = nixpkgs.legacyPackages.${system};
          in
          pkgs.symlinkJoin ({
            name = pkg.name + "-wrapped";
            paths = [ pkg ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              cd "$out"
              for p in ${builtins.toString pathsToWrap}
              do
                wrapProgram "$out/$p" \
                  --prefix PATH : "${prefixBinPath}" \
                  --suffix PATH : "${suffixBinPath}" \
                  ${builtins.toString extraWrapProgramArgs}
              done
            '';
          } // otherArgs);

        mkEditorTools = { pkgs }:
          with pkgs; [
            # misc
            multimarkdown
            jq
            editorconfig-core-c

            # shell
            shfmt
            shellcheck

            # python
            python-language-server
            black
            python3Packages.pyflakes
            python3Packages.isort

            # nix
            unstable.nil # nix lsp
            nixfmt
            nixpkgs-fmt

            # tex
            texlab

            # scala
            unstable.metals

            # dhall
            unstable.dhall-lsp-server
          ];
      };
    in {
      nixosConfigurations.nixos-home = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # add unstable overlay
          ({
            nixpkgs.overlays = [
              nixos-unstable-overlay
              nixpkgs-master-overlay
              nixpkgs-local-overlay
            ];
          })

          # registry entries
          ({
            nix.registry = {
              stable.flake = inputs.nixpkgs;
              osUnstable.flake = inputs.nixpkgs-unstable;
              unstable.flake = inputs.nixpkgs-pkgs-unstable;
              master.flake = inputs.nixpkgs-master;
              local.flake = inputs.nixpkgs-local;
            };
          })

          # nix path to correspond to my flakes
          ({
            nix.nixPath = [
              "nixpkgs=${inputs.nixpkgs}"
              "unstable=${inputs.nixpkgs-unstable}"
            ];
          })

          # get rid of default shell aliases;
          # see also: https://discourse.nixos.org/t/fish-alias-added-by-nixos-cant-delete/19626/3
          ({ lib, ... }: { environment.shellAliases = lib.mkForce { }; })

          # load cachix caches; generated through `cachix use -m nixos <cache-name>`
          ./cachix.nix

          # load system config
          ./system.nix

          # fonts, mainly for starship-prompt at the time of writing
          # also for "tide" prompt (fish)
          ({ pkgs, ... }: {
            fonts.fonts = with pkgs.unstable;
              [
                (nerdfonts.override {
                  fonts = [
                    "JetBrainsMono" # wezterm default font
                    "LiberationMono" # I just like this font :)
                    "FiraCode"
                    "DroidSansMono"
                    "NerdFontsSymbolsOnly"
                  ];
                })
              ];
          })

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
