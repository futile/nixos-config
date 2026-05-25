{ pkgs, ... }:
let
  signal-desktop = pkgs.symlinkJoin {
    name = "signal-desktop";
    paths = [ pkgs.signal-desktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/signal-desktop \
        --add-flags '--password-store=gnome-libsecret' \
        --add-flags '--use-tray-icon'
    '';
  };
in
{
  home.packages = [ signal-desktop ];
}
