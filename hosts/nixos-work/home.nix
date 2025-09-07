{
  config,
  pkgs,
  flake-inputs,
  thisFlakePath,
  ...
}:
let
  flakeRoot = flake-inputs.self.outPath;
in
{
  imports =
    let
      home-modules = "${flakeRoot}/home-modules";
    in
    [
      "${home-modules}/base.nix"
      "${home-modules}/shell-common.nix"
      # "${home-modules}/helix.nix"
      "${home-modules}/git.nix"
      "${home-modules}/git-extra.nix"
      "${home-modules}/jj.nix"
      "${home-modules}/fish.nix"
      "${home-modules}/nushell.nix"
      "${home-modules}/desktop-common.nix"
      "${home-modules}/desktop-gdrive-keepassxc.nix"
      # "${home-modules}/vivaldi.nix"

      # "${home-modules}/hyprland.nix"

      # > VA-API is enabled by default for Intel GPUs [10] if you are using Firefox 115 or a later version. For other GPUs, set media.ffmpeg.vaapi.enabled to true in about:config.
      # from https://wiki.archlinux.org/title/Firefox#Hardware_video_acceleration
      "${home-modules}/firefox.nix"

      "${home-modules}/zoom.nix"
      "${home-modules}/wezterm.nix"
      # "${home-modules}/doom-emacs.nix" # emacs drains cpu for no reason :(
      "${home-modules}/nvim-lazy.nix"
      # flake-inputs.hyprland.homeManagerModules.default

      "${home-modules}/zellij.nix"
      # "${home-modules}/sbt.nix"
      "${home-modules}/yazi.nix"
      "${home-modules}/mpv.nix"

      # for Zencoder.ai.. (:
      "${home-modules}/vscode.nix"
    ];

  xdg = {
    enable = true;
    configFile =
      let
        dotdir = "${config.home.homeDirectory}/nixos/dotfiles/hyprland";
      in
      {
        "hypr/local.conf".source = config.lib.file.mkOutOfStoreSymlink "${dotdir}/local.conf";
      };
  };

  home = {
    packages =
      # bound packages
      [ ]
      ++
        # packages from stable
        (with pkgs; [
          # compile stuff, for convenience I guess; but generally want to get rid of it
          ccache
          gcc
          gdb

          # AI etc.
          claude-code

          # messengers
          signal-desktop
          tdesktop
          discord
          # slack
          # fix for screen sharing (hopefully), from https://discourse.nixos.org/t/slack-screensharing-gnome-wayland/35585/8
          # (slack.overrideAttrs (oldAttrs: rec {
          #   # version = "4.35.126";
          #   # src = pkgs.fetchurl {
          #   #   url =
          #   #     "https://downloads.slack-edge.com/releases/linux/${version}/prod/x64/slack-desktop-${version}-amd64.deb";
          #   #   sha256 = "sha256-ldFASntF8ygu657WXwk/XlpHzB+S9x8SjAOjjDKsvCs=";
          #   # };
          #
          #   fixupPhase = ''
          #     sed -i -e 's/,"WebRTCPipeWireCapturer"/,"LebRTCPipeWireCapturer"/' $out/lib/slack/resources/app.asar
          #
          #     rm $out/bin/slack
          #     makeWrapper $out/lib/slack/slack $out/bin/slack \
          #       --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
          #       --suffix PATH : ${lib.makeBinPath [ pkgs.xdg-utils ]} \
          #       --add-flags "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer"
          #   '';
          # }))
          # element-desktop # known bug: https://github.com/NixOS/nixpkgs/issues/120228

          # rust tools
          rustup
          cargo-edit

          # misc
          # texlive.combined.scheme-full
          # zotero
          # protonvpn-cli

          # hardware stuff
          # v4l-utils # webcam utils
          radeontop
        ])
      ++
        # packages from master
        (with pkgs.master; [ ])
      ++
        # packages from other nixpkgs branches
        [ ];

    sessionVariables = {
      EDITOR = "nvim";
    };

    stateVersion = "22.11";
  };
}
