{ ... }: {
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      # enable ipv6 support inside docker
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
    };
  };
}
