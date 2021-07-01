{ inputs, ... }:
{ config, pkgs, ... }: {
  programs.fish = {
    enable = true;

    plugins = [{
      name = "foreign-env";
      src = inputs.fish-foreign-env;
    }];

    shellAliases = {
      sshuttle-comsys = "sshuttle --dns -vv -r rath@login.comsys.rwth-aachen.de 137.226.12.0/24 137.226.13.0/24 137.226.59.0/24 137.226.113.0/26 2a00:8a60:1014::/48 -x 137.226.13.22 -x 137.226.13.41 -x 137.226.13.42 -x 137.226.13.43 -x 137.226.13.49 -x 137.226.13.55 -x 137.226.59.41";
    };

    functions = {
      does_my_fish_config_work = {
        body = ''
          echo "yes it does"
        '';
      };
    };
  };
}
