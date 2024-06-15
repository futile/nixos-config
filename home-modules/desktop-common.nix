{ pkgs, config, thisFlakePath, flake-inputs, system, ... }:

{
  home = {
    packages =
      # packages from stable
      (with pkgs; [
        # misc
        python3 # just for a quick shell, math etc.
        libreoffice # open word/excel/etc. files

        # music/sound
        spotify
        pavucontrol

        # nix tools, so I can do some nixpkgs-stuff if I want to
        nix-prefetch-git
        nix-prefetch-github
        nixpkgs-review
        nixpkgs-fmt
        nix-diff

        # image editing
        inkscape
        gimp

        # screenshots
        spectacle

        # organization/todos etc.
        obsidian

        # useful gui tools
        wofi

        # useful cmdline-tools
        just
        dtrx
        tokei
        magic-wormhole
        trippy
        lazygit
        lazydocker
        dig
        tldr
        jq
        kondo # for cleaning (old) build artifacts, cache folders etc. interactively

        # development
        conda
        sublime-merge
        dbeaver-bin
        scala-cli
        earthly

        # cargo tools
        cargo-udeps
        cargo-feature

        # debugging stuff for hardware video accel
        # gpu-viewer
        # glxinfo

        # stuff I don't use atm
        # vscode
        # zellij
        # xsettingsd
        # lxappearance
        # nitrogen
        # procs # TODO move config from `nixos-home:~/.config/procs/config.toml` into this repo # stable, because fish completion on unstable is broken
        # sshuttle
        # tree # just using `exa` now
        # valgrind
        # tilix

      ]) ++
      # packages from other sources/nixpkgs branches
      [
        flake-inputs.nix-alien.packages.${system}.nix-alien
      ];

    file = {
      ".npmrc".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/npmrc";
      ".cargo/config.toml".source = config.lib.file.mkOutOfStoreSymlink
        "${thisFlakePath}/dotfiles/cargo/config.toml";
    };

    sessionPath = [ "$HOME/.npm-packages/bin" ];

    pointerCursor = {
      gtk.enable = true;
      x11.enable = true;

      package = pkgs.my-custom-packages.phinger-cursors-extended;
      name = "phinger-cursors-light-extended";

      size = 64;
    };
  };

  # at the time of writing: for pointerCursor.gtk.enable
  gtk = {
    enable = true;
  };
}
