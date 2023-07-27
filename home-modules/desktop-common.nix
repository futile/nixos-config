{ pkgs, config, thisFlakePath, ... }:

{
  home = {
    packages =
      # packages from stable
      (with pkgs; [
        # misc
        python3 # just for a quick shell, math etc.
        libreoffice # open word/excel/etc. files

        # stuff I don't use atm
        # procs # TODO move config from `nixos-home:~/.config/procs/config.toml` into this repo # stable, because fish completion on unstable is broken
        # sshuttle
        # tree
        # valgrind
        # tilix
      ]) ++
      # packages from unstable
      (with pkgs.unstable; [
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

        # useful cmdline-tools
        just
        dtrx
        tokei
        magic-wormhole
        trippy
        lazygit

        # stuff I don't use atm
        # vscode
        # zellij
        # xsettingsd
        # lxappearance
        # nitrogen
      ]) ++
      # packages from master
      (with pkgs.master; [ ]) ++
      # packages from other nixpkgs branches
      [ ];

    file = {
      ".npmrc".source = config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/npmrc";
    };

    sessionPath = [ "$HOME/.npm-packages/bin" ];
  };
}
