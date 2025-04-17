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
      "${home-modules}/git-extra.nix"
      "${home-modules}/jj.nix"
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
      "${home-modules}/yazi.nix"
      "${home-modules}/mpv.nix"
      # caused rebuilding..
      # "${home-modules}/zed-editor.nix"
    ];

  home = {
    packages =
      # bound packages
      [ ] ++
      # packages from stable
      (with pkgs; [
        # compile stuff, for convenience I guess; but generally want to get rid of it
        ccache
        gcc
        gdb

        # messengers
        signal-desktop
        tdesktop
        discord
        slack
        # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228 # don't use it currently

        # rust tools
        rustup
        cargo-edit
        cargo-nextest
        # conflicts with rustup, probably provided by rustup now? -- yes, but
        # the nixos version can be newer, so might be nice instead :)
        # rust-analyzer

        # misc
        # texlive.combined.scheme-full
        # zotero # disable due to CVE-2023-5217 in ‘zotero-6.0.27’ 
        protonvpn-gui # official GUI that has to be used now (:

        # hardware stuff
        v4l-utils # webcam utils
      ]) ++
      # packages from other nixpkgs branches
      [ ];

    sessionVariables = { EDITOR = "nvim"; };

    stateVersion = "22.05";
  };

  # see also system's 'default.nix'
  # alternative I could use (only saw this later): https://gist.github.com/LnL7/ff53b4d209ff363b0d5b60c918147f4d
  systemd.user.services.x11-custom-auto-key-repeat = {
    Unit = {
      Description = "Change auto-repeat settings";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart =
        let
          script-name = "run-xset-script";
          script-pkg = pkgs.writeShellApplication {
            name = script-name;

            text = ''
              set -euo pipefail
              set -o xtrace

              xset r rate 150 30
            '';

            # not even required, but here for reference :)
            # runtimeInputs = [ pkgs.xlibs.xset ];
          };
        in
        "${script-pkg}/bin/${script-name}";
      RemainAfterExit = true;
    };

    Install = { WantedBy = [ "graphical-session.target" ]; };
  };
}
