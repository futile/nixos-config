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
  };
}
