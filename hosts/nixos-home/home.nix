{ config, pkgs, flake-inputs, thisFlakePath, ... }:
let flakeRoot = flake-inputs.self.outPath;
in {
  imports =
    let home-modules = "${flakeRoot}/home-modules";
    in [
      "${home-modules}/base.nix"
      "${home-modules}/shell-common.nix"
      "${home-modules}/helix.nix"
      "${home-modules}/git.nix"
      "${home-modules}/fish.nix"
      "${home-modules}/nushell.nix"
      "${home-modules}/desktop-common.nix"
      "${home-modules}/desktop-gdrive-keepassxc.nix"
      "${home-modules}/vivaldi.nix"
      "${home-modules}/firefox.nix"
      "${home-modules}/zoom.nix"
      "${home-modules}/wezterm.nix"
      "${home-modules}/doom-emacs.nix"
      "${home-modules}/nvim-lazy.nix"
      "${home-modules}/sbt.nix"
    ];

  home = {
    packages =
      # bound packages
      [ ] ++
      # packages from stable
      (with pkgs; [
        element-desktop # temp stable, until bug resolved

        # compile stuff, for convenience I guess; but generally want to get rid of it
        ccache
        gcc
        gdb
      ]) ++
      # packages from unstable
      (with pkgs.unstable; [
        # messengers
        signal-desktop
        tdesktop
        discord
        slack
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228

        # rust tools
        rustup
        cargo-edit
        # rust-analyzer # conflicts with rustup, probably provided by rustup now?

        # misc
        texlive.combined.scheme-full
        # zotero # disable due to CVE-2023-5217 in ‘zotero-6.0.27’ 
        protonvpn-cli

        # hardware stuff
        v4l-utils # webcam utils
      ]) ++
      # packages from master
      (with pkgs.master; [ ]) ++
      # packages from other nixpkgs branches
      [ ];

    sessionVariables = { EDITOR = "nvim"; };

    stateVersion = "22.05";

    # NOTE: Bug: with `phinger-cursors-light`:
    # ```
    # Dec 22 11:11:52 nixos-home .gnome-shell-wr[4033]: No cursor theme available, please install a cursor theme
    # Dec 22 11:11:52 nixos-home .gnome-shell-wr[4033]: Received an X Window System error.
    #                                                   This probably reflects a bug in the program.
    #                                                   The error was 'BadCursor (invalid Cursor parameter)'.
    #                                                     (Details: serial 402014 error_code 6 request_code 95 (core protocol) minor_code 0)
    #                                                     (Note to programmers: normally, X errors are reported asynchronously;
    #                                                      that is, you will receive the error a while after causing it.
    #                                                      To debug your program, run it with the MUTTER_SYNC environment
    #                                                      variable to change this behavior. You can then get a meaningful
    #                                                      backtrace from your debugger if you break on the mtk_x_error() function.)
    # ```
    # Therefore switching to `Adwaita` for now (on this system).
    pointerCursor = {
      package = pkgs.lib.mkForce pkgs.gnome.adwaita-icon-theme;
      name = pkgs.lib.mkForce "Adwaita";
    };
  };
}
