{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "mex";
  version = "0.6.3";

  src = fetchFromGitHub {
    owner = "mex-memory";
    repo = "mex";
    rev = "v${version}";
    hash = "sha256-bZ8xLbnIo3TXSRwNJvU5i76BFCSh7y3UVTmdd0ncJis=";
  };

  npmDepsHash = "sha256-LAso3ZZAuOQ3I35zJITKrlkzSCxxR9jnWbgPuQhwhQQ=";

  npmBuildScript = "build";

  dontNpmPrune = true;

  postInstall = ''
    mkdir -p "$out/lib/node_modules/mex-agent/templates"
    cp -r templates/* "$out/lib/node_modules/mex-agent/templates/"
    mkdir -p "$out/lib/node_modules/mex-agent/packages"
    cp -r packages/* "$out/lib/node_modules/mex-agent/packages/"
  '';

  meta = {
    description = "CLI engine for scaffold drift detection, pre-analysis, and targeted sync";
    homepage = "https://github.com/mex-memory/mex";
    license = lib.licenses.mit;
    mainProgram = "mex";
    platforms = lib.platforms.unix;
  };
}
