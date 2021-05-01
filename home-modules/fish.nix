{ inputs, ... }:
{ config, pkgs, ... }: {
  programs.fish = {
    enable = true;

    plugins = [{
      name = "foreign-env";
      src = inputs.fish-foreign-env;
    }];

    functions = {
      does_my_fish_config_work = {
        body = ''
          echo "yes it does"
        '';
      };
    };

    # {{{
    # do I need this? or already done by nix/home-manager?
    # this is already done by nixos actually (through a systemd-service I think),
    # seems to only be needed when running nix on a non-nixos system.
    # loginShellInit = ''
    #   if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    #     fenv source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    #   end

    #   if test -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    #     fenv source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    #   end
    # '';
    # }}}
  };
}
