{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "agent-safehouse";
  version = "0.9.0";

  src = fetchurl {
    url = "https://github.com/eugene1g/agent-safehouse/releases/download/v0.9.0/safehouse.sh";
    hash = "sha256-YcL3HuE++QiUQssTzwUMxnnnZ+xI2pdx59j4o+sqhpc=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/safehouse"
    patchShebangs "$out/bin/safehouse"

    runHook postInstall
  '';

  meta = {
    description = "macOS-native sandboxing for local agents";
    homepage = "https://github.com/eugene1g/agent-safehouse";
    license = lib.licenses.asl20;
    platforms = lib.platforms.darwin;
    mainProgram = "safehouse";
  };
}
