{ ... }: {
  # Set-up pipewire for audio.
  # Mostly from https://discourse.nixos.org/t/headphone-volume-resets-itself-to-100/13866/2
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
