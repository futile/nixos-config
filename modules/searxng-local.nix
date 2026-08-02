{ pkgs, ... }:
let
  environmentFile = "/var/lib/searx/searx.env";
in
{
  services.searx = {
    enable = true;
    openFirewall = false;
    configureNginx = false;
    configureUwsgi = false;
    redisCreateLocally = false;
    inherit environmentFile;

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        secret_key = "$SEARXNG_SECRET";
        limiter = false;
        image_proxy = false;
        public_instance = false;
      };
      search.formats = [
        "html"
        "json"
      ];
    };
  };

  systemd.services = {
    searx-secret = {
      description = "Create the local SearXNG secret";
      before = [ "searx-init.service" ];
      requiredBy = [ "searx-init.service" ];
      path = [
        pkgs.coreutils
        pkgs.openssl
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        secret_dir="$(dirname ${environmentFile})"
        install -d -m 0750 -o root -g searx "$secret_dir"

        if [[ ! -s ${environmentFile} ]]; then
          temporary_secret="$(mktemp "$secret_dir/.searx.env.XXXXXX")"
          trap 'rm -f "$temporary_secret"' EXIT
          printf 'SEARXNG_SECRET=%s\n' "$(openssl rand -hex 32)" > "$temporary_secret"
          chown root:searx "$temporary_secret"
          chmod 0640 "$temporary_secret"
          mv "$temporary_secret" ${environmentFile}
          trap - EXIT
        fi
      '';
    };

    searx-init = {
      requires = [ "searx-secret.service" ];
      after = [ "searx-secret.service" ];
    };
  };
}
