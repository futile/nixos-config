{ config, pkgs, flake-inputs, thisFlakePath, ... }:

let flakeRoot = flake-inputs.self.outPath;
in {
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
    let home-modules = "${flakeRoot}/home-modules";
    in [
      # fix apps not showing in spotlight etc.
      flake-inputs.mac-app-util.homeManagerModules.default

      # "${home-modules}/base.nix"
      "${home-modules}/shell-common.nix"
      "${home-modules}/git.nix"
      "${home-modules}/fish.nix"
      # "${home-modules}/desktop-common.nix"
      "${home-modules}/wezterm.nix"
      "${home-modules}/nvim-lazy.nix"

      "${home-modules}/mac-fix-home-end.nix"
    ];

  programs.git = {
    extraConfig = {
      # rerere.enabled = true;

      git-town = {
        ship-delete-tracking-branch = "false";
        sync-feature-strategy = "rebase";
        sync-perennial-strategy = "rebase";
        sync-upstream = "true";
      };
    };

    aliases = {
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

  home.packages =
    # bound packages
    [ ] ++
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
      tldr
      jq
      yq
      dyff # semantic yaml diffing
      kondo # for cleaning (old) build artifacts, cache folders etc. interactively
      # libtree # broken on aarch-64! # for checking nested deps for Nix builds etc.
      socat
      duf # better du & df
      nvtopPackages.apple # video/gpu stats
      unixtools.watch

      # for now here manually, instead of "git-extra.nix"
      git-town
      mergiraf
      pre-commit

      # currently broken build (on macos (only?)), something about "permission denied" (some folder permissions in downloaded sources maybe? but dunno)
      # issue: https://github.com/NixOS/nixpkgs/issues/394068
      # gitbutler

      # see https://tableplus.com/, free with tab-/window-count limitations
      # tableplus # getting this through brew instead, more up-to-date + postgresql:// links work

      # development
      # conda
      # sublime-merge # license allows "unrestricted evaluation period"; but not available for aarch64 :(
      # dbeaver-bin
      # scala-cli
      # earthly

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
      mpv

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

    ".cargo/config.toml".source = config.lib.file.mkOutOfStoreSymlink
      "${thisFlakePath}/dotfiles/cargo/config.toml";
  };

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
  };

  # not using this yet, needs to use `.text = ''...` when I do
  # file = {
  #   ".npmrc".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/npmrc";
  # };
  # sessionPath = [ "$HOME/.npm-packages/bin" ];

  # PATH for golang go install'd binaries
  home.sessionPath = [ "$HOME/go/bin" ];

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
}
