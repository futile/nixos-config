{ flake-inputs, system, ... }:
{
  imports = [ flake-inputs.home-manager.nixosModules.home-manager ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  # forward flake-inputs to all home-modules
  home-manager.extraSpecialArgs = {
    inherit flake-inputs;
    inherit system;
  };
}
