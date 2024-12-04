{ pkgs, ... }: {
  # fonts, mainly for starship-prompt at the time of writing
  # also for "tide" prompt (fish)
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.liberation # no mono version of this?
    nerd-fonts.fira-code # `fira-mono` also exists
    nerd-fonts.droid-sans-mono
    nerd-fonts.symbols-only
    nerd-fonts.fantasque-sans-mono

    # old list:
    # (pkgs.nerdfonts.override {
    #   fonts = [
    #     "JetBrainsMono" # wezterm default font
    #     "LiberationMono" # I just like this font :)
    #     "FiraCode"
    #     "DroidSansMono"
    #     "NerdFontsSymbolsOnly"
    #     "FantasqueSansMono"
    #   ];
    # })
  ];
}
