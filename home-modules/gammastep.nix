# NOTE: Also requires the `geoclue2.nix` module (NOT a hm module!)
{
  # config,
  # pkgs,
  # flake-inputs,
  # thisFlakePath,
  ...
}:
{
  services.gammastep = {
    enable = true;
    tray = true;

    provider = "manual";

    # Loerick, Duesseldorf
    latitude = "51.246389";
    longitude = "6.727778";
  };
}
