{
  config,
  lib,
  pkgs,
  flake-inputs,
  thisFlakePath,
  ...
}:

let
  flakeRoot = flake-inputs.self.outPath;
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "frath";
  home.homeDirectory = "/Users/frath";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  imports =
    let
      home-modules = "${flakeRoot}/home-modules";
    in
    [
      # fix apps not showing in spotlight etc.
      # flake-inputs.mac-app-util.homeManagerModules.default

      "${home-modules}/base.nix"
      "${home-modules}/shell-common.nix"
      "${home-modules}/git.nix"
      "${home-modules}/jj.nix"
      "${home-modules}/nix-profile-snapshot.nix"
      # "${home-modules}/gitbutler.nix" # always builds from scratch, too annoying
      "${home-modules}/fish.nix"
      "${home-modules}/sbt.nix"
      # "${home-modules}/desktop-common.nix"
      "${home-modules}/wezterm.nix"
      "${home-modules}/nvim-lazy.nix"

      "${home-modules}/mac-fix-home-end.nix"
    ];

  targets.darwin = {
    # fix apps not showing in spotlight etc.
    copyApps.enable = true;
    linkApps.enable = false;
  };

  programs.firefox.configPath = "${config.xdg.configHome}/mozilla/firefox";

  programs.git = {
    settings = {
      # rerere.enabled = true;

      git-town = {
        ship-delete-tracking-branch = "false";
        sync-feature-strategy = "rebase";
        sync-perennial-strategy = "rebase";
        sync-upstream = "true";
      };

      alias = {
        # aliases created by/for `git-town`
        append = "town append";
        # compress = "town compress";
        contribute = "town contribute";
        diff-parent = "town diff-parent";
        hack = "town hack";
        kill = "town kill";
        observe = "town observe";
        park = "town park";
        prepend = "town prepend";
        # propose = "town propose";
        rename-branch = "town rename-branch";
        repo = "town repo";
        set-parent = "town set-parent";
        sync = "town sync";
      };
    };
  };

  home.packages =
    # bound packages
    [ ]
    ++
      # packages from pkgs
      (with pkgs; [
        # let's try out brave, since chromium is blocking uBlock now :)
        brave

        # compile stuff, for convenience I guess; but generally want to get rid of it
        # ccache
        # gcc
        # gdb

        # rust & cargo tools
        rustup
        cargo-edit
        cargo-udeps
        # cargo-vet # sadly broken for now, see https://github.com/NixOS/nixpkgs/pull/370510
        cargo-nextest
        cargo-release
        git-cliff
        # cargo-audit # broken for now due to Rust 1.80/`time`-lib fallout, should (?) be fixed by v0.20.1 soon

        # misc
        python3 # just for a quick shell, math etc.
        # libreoffice # open word/excel/etc. files
        yarn-berry # looks like I might just need this sometimes. -berry is the 4.x version, while just yarn is 1.x
        nodejs

        # TESTING; stuff I want to test, throw back out if I don't use it!
        # oils-for-unix # currently broken (2025-02-10)

        # nix tools, so I can do some nixpkgs-stuff if I want to
        nix-prefetch-git
        nix-prefetch-github
        nixpkgs-review
        nixpkgs-fmt
        nix-diff

        # image editing
        # inkscape
        # gimp

        # useful cmdline-tools
        just
        # dtrx # broken on aarch-64!
        tokei
        # trippy
        # lazygit
        # lazydocker
        # dig
        jq
        yq
        dyff # semantic yaml diffing
        kondo # for cleaning (old) build artifacts, cache folders etc. interactively
        # libtree # broken on aarch-64! # for checking nested deps for Nix builds etc.
        socat
        duf # better du & df
        nvtopPackages.apple # video/gpu stats
        unixtools.watch
        sshuttle

        # `tealdeer` is a faster reimplementation of `tldr`
        # tldr
        tealdeer

        # for now here manually, instead of "git-extra.nix"
        git-town
        mergiraf
        # pre-commit # pulls in .NET SDK which requires building Swift from source on Darwin

        # see https://tableplus.com/, free with tab-/window-count limitations
        # tableplus # getting this through brew instead, more up-to-date + postgresql:// links work

        # development
        # conda
        # sublime-merge # license allows "unrestricted evaluation period"; but not available for darwin :( https://search.nixos.org/packages?channel=unstable&show=sublime-merge&from=0&size=50&sort=relevance&type=packages&query=sublime-merge
        # dbeaver-bin
        scala-cli
        jdk
        # earthly
        wrangler
        pnpm

        # AI
        # 2026-04-09 keeping opencode in my profile for now, since it updates so often, and I don't want to wait for nixos-unstable every time
        # opencode
        skills # https://skills.sh/
        sandbox-runtime # https://github.com/anthropic-experimental/sandbox-runtime
        my-custom-packages.agent-safehouse # https://agent-safehouse.dev/

        # working with rustc's `-Zself-profile` output: https://github.com/rust-lang/measureme
        # measureme

        # cf stuff, but I get these via homebrew 🙃
        # cf-paste
        # vault # vault for secrets, needed for `dbmgr`
        vault-bin # with ui, conflicts with `vault`

        nerd-fonts.jetbrains-mono
        nerd-fonts.liberation # no mono version of this?
        nerd-fonts.fira-code # `fira-mono` also exists
        nerd-fonts.droid-sans-mono
        nerd-fonts.symbols-only
        nerd-fonts.fantasque-sans-mono

        # old list: (also see `modules/fonts.nix`)
        # (nerdfonts.override {
        #   fonts = [
        #     "JetBrainsMono" # wezterm default font
        #     "LiberationMono" # I just like this font :)
        #     "FiraCode"
        #     "DroidSansMono"
        #     "NerdFontsSymbolsOnly"
        #     "FantasqueSansMono"
        #   ];
        # })

        # el music
        spotify

        # el video
        # 2026-02-02 apparently requires building swift locally (now?) which I really don't wanna..
        # mpv

        # el pdf viewer with auto-reload support
        skimpdf

        # You can also create simple shell scripts directly inside your
        # configuration. For example, this adds a command 'my-hello' to your
        # environment:
        # (pkgs.writeShellScriptBin "my-hello" ''
        #   echo "Hello, ${config.home.username}!"
        # '')
      ]);

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';

    ".cargo/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/cargo/config.toml";
  };

  programs.bash.bashrcExtra = ''
    . /Users/frath/.local/share/cloudflare-warp-certs/config.sh
  '';

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/frath/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    SSH_AUTH_SOCK = "/opt/homebrew/var/run/yubikey-agent-cloudflare.sock";
  };

  # not using this yet, needs to use `.text = ''...` when I do
  # file = {
  #   ".npmrc".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/npmrc";
  # };
  # sessionPath = [ "$HOME/.npm-packages/bin" ];

  # PATH for golang go install'd binaries
  home.sessionPath = [ "$HOME/go/bin" ];

  my.nixProfileSnapshot = {
    enable = true;
    hostName = "hm-cf";
    watchPath = "${config.home.homeDirectory}/.local/state/nix/profiles";
  };

  # After activation, check if any app binaries changed and remind to re-grant
  # permissions if so. The script is interactive (opens System Settings panes)
  # so it cannot run fully here — it detects changes and prints a reminder.
  home.activation.macosPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! bash "${flakeRoot}/hosts/hm-cf/setup-macos-permissions.sh" --check-only 2>/dev/null; then
      echo ""
      echo "One or more app binaries changed. Run: just setup-macos-permissions"
      echo ""
    fi
  '';

  # One-time reminder to enable Touch ID for sudo.
  # /etc/pam.d/sudo_local survives macOS updates, so this only fires once per machine.
  home.activation.sudoTouchId = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! grep -qF "pam_tid.so" /etc/pam.d/sudo_local 2>/dev/null; then
      echo ""
      echo "Touch ID for sudo is not enabled. Run: just setup-macos-sudo-touchid"
      echo ""
    fi
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # need to do this in `flake.nix`! (or differently, but doesn't work this way)
  # nixpkgs.overlays = ;

  # nix configuration
  nix = {
    enable = true; # hopefully /etc/nix also still works xD

    # registry entries
    registry = {
      unstable.flake = flake-inputs.nixpkgs;
      punstable.flake = flake-inputs.nixpkgs-pkgs-unstable;
      # master.flake = flake-inputs.nixpkgs-master;
      # local.flake = flake-inputs.nixpkgs-local;
    };

    # nix path to correspond to my flakes
    nixPath = [
      "nixpkgs=${flake-inputs.nixpkgs}"
      "unstable=${flake-inputs.nixpkgs}"
      "punstable=${flake-inputs.nixpkgs-pkgs-unstable}"
    ];
  };

  # I want my fonts (:
  fonts.fontconfig.enable = true;

  programs.fish.shellInit = ''
    fenv "source /Users/frath/.local/share/cloudflare-warp-certs/config.sh"
  '';

  programs.fish.functions = {
    safe = {
      body = ''
        safehouse \
          --env \
          --enable=wide-read,ssh,shell-init \
          $argv
      '';
    };

    safe-opencode = {
      body = ''
        set -lx OPENCODE_PERMISSION '{"*":"allow"}'

        if test -x "$HOME/.git-ai/bin/git-ai"; \
            and not "$HOME/.git-ai/bin/git-ai" bg status >/dev/null 2>&1; \
            and test -e "$HOME/.git-ai/internal/daemon/daemon.lock"; \
            and not test -S "$HOME/.git-ai/internal/daemon/control.sock"
          rm "$HOME/.git-ai/internal/daemon/daemon.lock"
        end

        safehouse \
          --env \
          --enable=wide-read,ssh,shell-init,clipboard \
          --add-dirs=(string join : \
            "$HOME/.local" \
            "$HOME/.cache" \
            "$HOME/.config/opencode" \
            "$HOME/.git-ai/internal" \
            "$HOME/repos" \
            "$HOME/nixos" \
            "$TMPDIR/opencode") \
          opencode \
          $argv
      '';
    };

    os = {
      body = ''
        # `opencode mcp auth cf-portal` prompts to re-authenticate even when
        # credentials are still valid. Check first so `os` stays non-interactive
        # unless cf-portal actually needs fresh OAuth credentials.
        set -l cf_portal_auth_status (opencode mcp auth list | string collect | string replace -ar '\e\[[0-9;]*m' "")

        if string match -q "*cf-portal*not*authenticated*" -- $cf_portal_auth_status
          opencode mcp auth cf-portal
          or return $status
        end

        opencode auth login https://opencode.cloudflare.dev
        and safe-opencode $argv
      '';
    };

    oc-browser = {
      body = ''
        # Dedicated Brave profile for the chrome-devtools OpenCode MCP server.
        # Keep this in sync with ~/.config/opencode/opencode.jsonc.
        brave \
          --remote-debugging-port=9222 \
          --user-data-dir="$HOME/Library/Application Support/BraveSoftware/Brave-Browser-MCP" \
          $argv \
          >/dev/null 2>&1 &

        disown
      '';
    };
  };
}
