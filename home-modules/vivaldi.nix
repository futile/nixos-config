{ pkgs, ... }: {
  home.packages = with pkgs.unstable;
    [
      (vivaldi.override {
        proprietaryCodecs = true;
        vivaldi-ffmpeg-codecs = vivaldi-ffmpeg-codecs;

        # enabling this segfaults vivaldi at startup
        # enableWidevine = true;
        # widevine-cdm = vivaldi-pkgs.widevine-cdm;
      })
    ];
}
