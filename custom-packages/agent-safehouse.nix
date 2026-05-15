{
  lib,
  stdenvNoCC,
  fetchurl,
  bashInteractive,
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
    # Safehouse's --env mode uses the Bash-specific `compgen` builtin to enumerate
    # inherited environment variables. nixpkgs' non-interactive `bash` build omits
    # that builtin, so use `bashInteractive` instead of the default patchShebangs target.
    substituteInPlace "$out/bin/safehouse" \
      --replace-fail '#!/usr/bin/env bash' '#!${lib.getExe bashInteractive}'

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
