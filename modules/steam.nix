{ pkgs, ... }:
{
  # from https://wiki.nixos.org/wiki/Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };
}
