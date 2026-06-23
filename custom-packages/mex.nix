{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "mex";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "mex-memory";
    repo = "mex";
    rev = "v${version}";
    hash = "sha256-5hVecdT9NIfoz+vv7LyIIpnHK9HwsVUrHNDG+ZyyK4Y=";
  };

  npmDepsHash = "sha256-slCu4cuJVAol1GJfBnIb9KxjbHZ9wmZ4sALuQguCAlU=";

  npmBuildScript = "build";

  postInstall = ''
    mkdir -p "$out/lib/node_modules/mex-agent/templates"
    cp -r templates/* "$out/lib/node_modules/mex-agent/templates/"
  '';

  meta = {
    description = "CLI engine for scaffold drift detection, pre-analysis, and targeted sync";
    homepage = "https://github.com/mex-memory/mex";
    license = lib.licenses.mit;
    mainProgram = "mex";
    platforms = lib.platforms.unix;
  };
}
