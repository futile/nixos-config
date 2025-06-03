{ ... }:
{
  # Set-up pipewire for audio.
  # Mostly from https://discourse.nixos.org/t/headphone-volume-resets-itself-to-100/13866/2
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # from https://nixos.wiki/wiki/PipeWire#Bluetooth_Configuration
  # environment.etc = {
  #   "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
  #     bluez_monitor.properties = {
  #       ["bluez5.enable-sbc-xq"] = true,
  #       ["bluez5.enable-msbc"] = true,
  #       ["bluez5.enable-hw-volume"] = true,
  #     }
  #   '';
  # };

  # not sure if this prevents hsp from working
  # ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
}
