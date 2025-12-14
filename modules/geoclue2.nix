{
  services.geoclue2 = {
    enable = true;
    # if using beaconDB
    # geoProviderUrl = "https://api.beacondb.net/v1/geolocate";

    appConfig.gammastep = {
      isAllowed = true;
      isSystem = false;
    };
  };

  location.provider = "geoclue2";
}
