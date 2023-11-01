{ ... }: {
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      # enable ipv6 support inside docker
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
    };
  };

  # Allow access from inside docker containers to the host (usually using host.docker.internal/172.17.0.1)
  # based on https://stackoverflow.com/a/52560944
  networking.firewall.extraCommands = ''
    iptables -A INPUT -i br+ -j ACCEPT
    iptables -A INPUT -i docker0 -j ACCEPT
  '';
}
