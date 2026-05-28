{
  lib,
  python3,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  ast-grep,
  onnxruntime,
  pkg-config,
  openssl,
}:

# Kept for manual Headroom experiments. The nixos-work Codex stack does not
# install or start this package by default; see
# docs/codex-token-optimization-stack.md#headroom-evaluation.
python3.pkgs.buildPythonApplication rec {
  pname = "headroom-ai";
  version = "0.22.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "chopratejas";
    repo = "headroom";
    tag = "v${version}";
    hash = "sha256-xTN4tO2wafk9zkQnSdXiWeKrCnefyFtNr2WM8s6/jTg=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit pname version src;
    hash = "sha256-WQBvil0bsS6/Z6b+uRauwOQq4VZ57VwAoghcyFdVgLE=";
  };

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
  ];

  buildInputs = [
    onnxruntime
    openssl
  ];

  postPatch = ''
        substituteInPlace pyproject.toml \
          --replace-fail 'version = "0.9.1"' 'version = "${version}"'

    substituteInPlace crates/headroom-core/Cargo.toml \
      --replace-fail '"ort-download-binaries-rustls-tls"' '"ort-load-dynamic"'

    patch -p1 < ${./patches/headroom-codex-ws-oversize-preflight.patch}

    substituteInPlace headroom/proxy/models.py \
      --replace-fail 'from dataclasses import InitVar, dataclass, field' $'from dataclasses import InitVar, dataclass, field\nimport os' \
      --replace-fail 'from headroom.providers.registry import ProviderApiOverrides' $'from headroom.providers.registry import ProviderApiOverrides\n\n\ndef _env_int_or_none(name: str) -> int | None:\n    raw = os.environ.get(name, "").strip()\n    if not raw:\n        return None\n    try:\n        return int(raw)\n    except ValueError:\n        return None' \
      --replace-fail 'compression_max_workers: int | None = None' 'compression_max_workers: int | None = field(default_factory=lambda: _env_int_or_none("HEADROOM_COMPRESSION_MAX_WORKERS"))'
  '';

  env = {
    ORT_STRATEGY = "system";
    ORT_LIB_LOCATION = "${lib.getLib onnxruntime}/lib";
    ORT_PREFER_DYNAMIC_LINK = "true";
    ORT_DYLIB_PATH = "${lib.getLib onnxruntime}/lib/libonnxruntime.so";
  };

  dependencies = with python3.pkgs; [
    click
    fastapi
    h2
    httpx
    litellm
    magika
    mcp
    openai
    pydantic
    rich
    sqlite-vec
    tiktoken
    transformers
    uvicorn
    watchdog
    websockets
    zstandard
    python3.pkgs."opentelemetry-api"
    python3.pkgs.onnxruntime
  ];

  pythonRelaxDeps = [
    "litellm"
  ];

  pythonRemoveDeps = [
    "ast-grep-cli"
  ];

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ ast-grep ]}"
    "--set ORT_DYLIB_PATH ${lib.getLib onnxruntime}/lib/libonnxruntime.so"
    "--prefix LD_LIBRARY_PATH : ${lib.getLib onnxruntime}/lib"
  ];

  pythonImportsCheck = [
    "headroom"
  ];

  meta = {
    description = "Context optimization layer for LLM applications and coding agents";
    homepage = "https://github.com/chopratejas/headroom";
    changelog = "https://github.com/chopratejas/headroom/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "headroom";
    platforms = lib.platforms.linux;
  };
}
