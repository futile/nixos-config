{ pkgs, ... }:
# google-drive and keepassxc are currently intertwined, so set them up together
let
  my-google-drive-ocamlfuse = pkgs.google-drive-ocamlfuse;
  my-keepassxc = pkgs.keepassxc;
in
{
  home.packages = [ my-google-drive-ocamlfuse my-keepassxc ];

  systemd.user.services = {
    google-drive-ocamlfuse = {
      Unit = { Description = "Automount google drive"; };

      Service = {
        Type = "simple";
        ExecStart =
          "${my-google-drive-ocamlfuse}/bin/google-drive-ocamlfuse -f %h/GoogleDrive";
      };

      Install = { WantedBy = [ "default.target" ]; };
    };

    keepassxc = {
      Unit = {
        Description = "Autostart Keepassxc";
        After =
          [ "graphical-session-pre.target" "google-drive-ocamlfuse.service" ];
        Wants = [ "google-drive-ocamlfuse.service" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${my-keepassxc}/bin/keepassxc";
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}
