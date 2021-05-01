{
  description = "Full Flake Panic!";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-20.09"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    home-manager = { 
      url = "github:nix-community/home-manager/release-20.09"; 
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    fish-foreign-env = {
      url = "github:oh-my-fish/plugin-foreign-env";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: 
  let 
    nixos-unstable-overlay = final: prev: {
      unstable = import nixpkgs-unstable {
        system = prev.system;
        config.allowUnfree = true;
      };
    };
  in
  rec {
    system = "x86_64-linux";

      lib = {
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

    nixosConfigurations.nixos-home = nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [ 
        # add unstable overlay
        ({ 
          nixpkgs.overlays = [ nixos-unstable-overlay ]; 
        })

        # load system config
        ./system.nix 

        # {{{
        # prepare arguments to our home-manager config.
        # we use an option to pass them.
        # from: https://discourse.nixos.org/t/variables-for-a-system/2342
        # ({ lib, ... }: { 
        #   options.hm-inputs = lib.mkOption {
        #     type = lib.types.attrs;
        #     default = { 
        #       inherit (inputs) fish-foreign-env;
        #     };
        #   };
        # })
        # we now simply pass 'inputs' via specialArgs.
        # -> nope, this didn't work, because it's not a module, just home-manager
        #    stuff. we just make home.nix a curried function and pass an argument.
        # }}}

        # user config
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.felix = import ./home.nix { inherit inputs lib; };
        }
    ];
  };
};
}
