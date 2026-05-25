{
  config,
  pkgs,
  flake-inputs,
  thisFlakePath,
  system,
  ...
}:
let
  flakeRoot = flake-inputs.self.outPath;
  # KeePassXC sometimes opens a normal window even with --minimized on Niri.
  # Once the tray exists, closing that window follows KeePassXC's
  # MinimizeOnClose/MinimizeToTray settings and leaves it running in the tray.
  closeKeePassXCStartupWindow = pkgs.writeShellScript "close-keepassxc-startup-window" ''
    sleep 1

    window_id="$(
      ${pkgs.niri}/bin/niri msg -j windows \
        | ${pkgs.jq}/bin/jq -r 'map(select(.app_id == "org.keepassxc.KeePassXC")) | first | .id // empty'
    )"

    if [[ -n "$window_id" ]]; then
      ${pkgs.niri}/bin/niri msg action close-window --id "$window_id"
    fi
  '';
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
      "${home-modules}/agents.nix"
      "${home-modules}/codex.nix"
      "${home-modules}/gascity.nix"
      "${home-modules}/nix-profile-snapshot.nix"
      "${home-modules}/fish.nix"
      "${home-modules}/nushell.nix"
      "${home-modules}/desktop-common.nix"
      "${home-modules}/desktop-gdrive.nix"
      "${home-modules}/signal-desktop.nix"
      # "${home-modules}/vivaldi.nix"

      # "${home-modules}/hyprland.nix"

      "${home-modules}/gammastep.nix"
      "${home-modules}/niri.nix"

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
    autostart.enable = true;
    configFile =
      let
        hyprland = "${config.home.homeDirectory}/nixos/dotfiles/hyprland";
        noctalia = "${config.home.homeDirectory}/nixos/dotfiles/noctalia/nixos-work";
      in
      {
        "hypr/local.conf".source = config.lib.file.mkOutOfStoreSymlink "${hyprland}/local.conf";

        # don't symlink this, it changes whenever light/dark mode changes etc.
        # "noctalia/colors.json".source = config.lib.file.mkOutOfStoreSymlink "${noctalia}/colors.json";

        "noctalia/notification-rules.json".source =
          config.lib.file.mkOutOfStoreSymlink "${noctalia}/notification-rules.json";
        "noctalia/plugins.json".source = config.lib.file.mkOutOfStoreSymlink "${noctalia}/plugins.json";
        "noctalia/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${noctalia}/settings.json";
        "noctalia/user-templates.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${noctalia}/user-templates.toml";

        # systemd-xdg-autostart-generator ignores KeePassXC's desktop-file
        # tray/delay hints. Delay the generated unit until the shell tray is up,
        # then close any initial window that KeePassXC still opens.
        "systemd/user/app-org.keepassxc.KeePassXC@autostart.service.d/delay-start.conf".text = ''
          [Service]
          ExecStartPre=${pkgs.coreutils}/bin/sleep 7
          ExecStart=
          ExecStart=${config.programs.keepassxc.package}/bin/keepassxc --minimized
          ExecStartPost=${closeKeePassXCStartupWindow}
        '';
      };
  };

  programs.keepassxc = {
    enable = true;
    # Keep this disabled so KeePassXC can manage its own XDG autostart entry
    # through the in-app startup setting.
    autostart = false;
  };

  my.gascity = {
    enable = true;
    supervisor.installOnActivation = true;
  };

  # 2026-04-29 new default path is this. before switching to this, I did:
  # > To migrate to the XDG path, move `~/.mozilla/firefox` to
  # > `$XDG_CONFIG_HOME/mozilla/firefox` and remove the old directory.
  # > Native messaging hosts are not moved by this option change.
  programs.firefox.configPath = "${config.xdg.configHome}/mozilla/firefox";

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
          # 2026-04-02 broken until https://nixpk.gs/pr-tracker.html?pr=505911
          # claude-code

          # messengers
          telegram-desktop
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
          cargo-nextest
          sccache

          # misc
          # texlive.combined.scheme-full
          # zotero
          my-custom-packages.llm-wiki
          # protonvpn-cli

          # hardware stuff
          # v4l-utils # webcam utils
          radeontop

          # 2026-04-29 this causes it to rebuild during `switch`, don't wanna 🙃
          # my-custom-packages.marker
        ])
      ++
        # packages from master
        (with pkgs.master; [ ])
      ++
        # packages from other nixpkgs branches
        [
          flake-inputs.nix-alien.packages.${system}.nix-alien
        ];

    # use locally-built `marker` if available
    sessionPath = [ "$HOME/gits/Marker/src-tauri/target/release" ];

    sessionVariables = {
      EDITOR = "nvim";

      # can also put this into ~/.cargo/config.toml, but I don't have this on all systems atm.
      # ref: https://github.com/mozilla/sccache?tab=readme-ov-file#usage
      RUSTC_WRAPPER = "sccache";
    };

    stateVersion = "22.11";
  };

  my.nixProfileSnapshot = {
    enable = true;
    hostName = "nixos-work";
    watchPath = "/nix/var/nix/profiles/per-user/${config.home.username}";
  };
}
