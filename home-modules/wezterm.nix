{
  config,
  pkgs,
  flake-inputs,
  thisFlakePath,
  ...
}:

let
  my-wezterm =
    if pkgs.stdenv.isLinux then
      pkgs.wezterm
    else
      (pkgs.lib.my.mkWrappedWithDeps {
        pkg = pkgs.wezterm;
        pathsToWrap = [
          "bin/wezterm"
          "bin/wezterm-gui"
          "bin/wezterm-mux-server"
        ];
        # HACK: This is super hacky, but will do for now.. 🙈
        suffix-deps = [
          "/Users/frath/.nix-profile"
          "/nix/var/nix/profiles/default"
        ];
      });
in
{
  # rolling wezterm by hand, as I don't like the upstream home-manager module
  home.packages = (
    [
      (my-wezterm)
    ]
    ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.xsel # for system clipboard, because wezterm ignores clipboard escape codes for security reasons
    ])
  );

  xdg = {
    enable = true;

    # symlink directly to this repo, for easier iteration/changes
    configFile."wezterm/wezterm.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${thisFlakePath}/dotfiles/wezterm/wezterm.lua";
    configFile."wezterm/colors/embark.toml".source =
      flake-inputs.wezterm-embark + "/colors/embark.toml";
  };
}
