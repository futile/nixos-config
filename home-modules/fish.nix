{ inputs, ... }:
{ config, pkgs, ... }: {
  programs.fish = {
    enable = true;
    package = pkgs.unstable.fish;

    plugins = [
      # Automatically sync environment variables set by sub-shells that are not fish.
      # https://github.com/oh-my-fish/plugin-foreign-env
      {
        name = "foreign-env";
        src = inputs.fish-foreign-env;
      }

      # Automatically rewrite `...` to `../../` while typing, also `!!` and `!$`.
      # https://github.com/nickeb96/puffer-fish
      {
        name = "puffer-fish";
        src = inputs.fish-puffer-fish;
      }

      # Tide-prompt.
      # https://github.com/IlanCosman/tide
      {
        name = "tide";
        src = inputs.fish-tide;
      }
    ];

    shellAliases = {
      # don't need this anymore, just keeping it around for reference
      # sshuttle-comsys = "sshuttle --dns -vv -r rath@login.comsys.rwth-aachen.de 137.226.12.0/24 137.226.13.0/24 137.226.59.0/24 137.226.113.0/26 2a00:8a60:1014::/48 -x 137.226.13.22 -x 137.226.13.41 -x 137.226.13.42 -x 137.226.13.43 -x 137.226.13.49 -x 137.226.13.55 -x 137.226.59.41";

      ls = "exa --icons --group-directories-first";
      l = "ls";
      la = "ls -la";
      lt = "exa --tree --git-ignore --icons --group-directories-first";
      ltl = "lt -l";
      lta = "lt -a";
      ltla = "lt -la";

      # let's try this out :) -- works great!
      cat = "bat";
    };

    functions = {
      does_my_fish_config_work = {
        body = ''
          echo "yes it does"
        '';
      };

      fish_user_key_bindings = {
        body = ''
          # '\a' is ctrl+g according to `fish_key_reader`
          bind \a 'magit'
        '';
      };
    };
  };

  # make sure these are enabled, without forcing a specific package
  # (so the specific package can be set somewhere else).
  programs.exa.enable = true;
  programs.bat.enable = true;
}
