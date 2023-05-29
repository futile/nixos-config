{ pkgs, ... }: {
  # fonts, mainly for starship-prompt at the time of writing
  # also for "tide" prompt (fish)
  fonts.fonts = [
    (pkgs.unstable.nerdfonts.override {
      fonts = [
        "JetBrainsMono" # wezterm default font
        "LiberationMono" # I just like this font :)
        "FiraCode"
        "DroidSansMono"
        "NerdFontsSymbolsOnly"
      ];
    })
  ];
}
