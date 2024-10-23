{ config, pkgs, flake-inputs, ... }: {
  programs.fish = {
    enable = true;
    package = pkgs.fish;

    plugins = [
      # Automatically sync environment variables set by sub-shells that are not fish.
      # https://github.com/oh-my-fish/plugin-foreign-env
      {
        name = "foreign-env";
        src = flake-inputs.fish-foreign-env;
      }

      # Automatically rewrite `...` to `../../` while typing, also `!!` and `!$`.
      # https://github.com/nickeb96/puffer-fish
      {
        name = "puffer-fish";
        src = flake-inputs.fish-puffer-fish;
      }

      # Tide-prompt.
      # https://github.com/IlanCosman/tide
      {
        name = "tide";
        src = flake-inputs.fish-tide;
      }
    ];

    shellAliases = {
      # don't need this anymore, just keeping it around for reference
      # sshuttle-comsys = "sshuttle --dns -vv -r rath@login.comsys.rwth-aachen.de 137.226.12.0/24 137.226.13.0/24 137.226.59.0/24 137.226.113.0/26 2a00:8a60:1014::/48 -x 137.226.13.22 -x 137.226.13.41 -x 137.226.13.42 -x 137.226.13.43 -x 137.226.13.49 -x 137.226.13.55 -x 137.226.59.41";

      ls = "eza --icons --group-directories-first";
      l = "ls";
      la = "ls -la";
      lt = "eza --tree --git-ignore --icons --group-directories-first";
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

    # adapted from https://discourse.nixos.org/t/using-fish-interactively-with-zsh-as-the-default-shell-on-macos/48402/7?u=futile
    loginShellInit = pkgs.lib.mkIf pkgs.stdenv.isDarwin ''
      # Nix
      if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
          source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
          # following is single user
          # source '/nix/var/nix/profiles/default/etc/profile.d/nix.fish'
      end
      # End Nix

      ################### Nix
      # Essential workaround for clobbered `$PATH` with nix-darwin.
      # Without this, both Nix and Homebrew paths are forced to the end of $PATH.
      # <https://github.com/LnL7/nix-darwin/issues/122#issuecomment-1345383219>
      # <https://github.com/LnL7/nix-darwin/issues/122#issuecomment-1030877541>
      #
      # A previous version of this snippet also included:
      #   - /run/wrappers/bin
      #   - /etc/profiles/per-user/$USER/bin # mwb needed if useGlobalPkgs used.
      #
      if test (uname) = Darwin
          fish_add_path --move --prepend --global \
            "${config.xdg.stateHome}/nix/profile/bin" \
            "/etc/profiles/per-user/$USER/bin" \
            /run/current-system/sw/bin \
            /nix/var/nix/profiles/default/bin

          # bind neo's home and end (requires adding "com.github.wez.wezterm" to the Karabiner Elements list for Home&End in terminals)
          bind \e\[H beginning-of-line
          bind \e\[F end-of-line
      end
    '';

    # adapted from https://github.com/orgs/Homebrew/discussions/4412#discussioncomment-8651316
    shellInit = pkgs.lib.mkIf pkgs.stdenv.isDarwin ''
      # if test -d /home/linuxbrew/.linuxbrew # Linux
      #   set -gx HOMEBREW_PREFIX "/home/linuxbrew/.linuxbrew"
      #   set -gx HOMEBREW_CELLAR "$HOMEBREW_PREFIX/Cellar"
      #   set -gx HOMEBREW_REPOSITORY "$HOMEBREW_PREFIX/Homebrew"
      if test -d /opt/homebrew # MacOS
        set -gx HOMEBREW_PREFIX "/opt/homebrew"
        set -gx HOMEBREW_CELLAR "$HOMEBREW_PREFIX/Cellar"
        set -gx HOMEBREW_REPOSITORY "$HOMEBREW_PREFIX/homebrew"
        fish_add_path -gP "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin";
        ! set -q MANPATH; and set MANPATH '''; set -gx MANPATH "$HOMEBREW_PREFIX/share/man" $MANPATH;
        ! set -q INFOPATH; and set INFOPATH '''; set -gx INFOPATH "$HOMEBREW_PREFIX/share/info" $INFOPATH;
      end
    '';
  };

  # make sure these are enabled, without forcing a specific package
  # (so the specific package can be set somewhere else).
  programs.eza.enable = true;
  programs.bat.enable = true;
}

