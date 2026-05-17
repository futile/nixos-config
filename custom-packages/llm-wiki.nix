{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchNpmDeps,
  nix-update-script,
  rustPlatform,
  cargo-tauri,
  desktop-file-utils,
  glib-networking,
  nodejs,
  npmHooks,
  openssl,
  pkg-config,
  protobuf,
  webkitgtk_4_1,
  wrapGAppsHook4,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "llm-wiki";
  version = "0.4.10";

  src = fetchFromGitHub {
    owner = "nashsu";
    repo = "llm_wiki";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mXn2CNXYkOMJxVPlc4H/KRfM6wvEdC3GMaaZRr7U0LI=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-Bg+h1+NlUa2vJ0+g+ypFGhXkxyWB2mMqT82MYUOEmGo=";

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-YGBpneK/qIMSvL+gIhBUSmolVm3S+h4E90e/s2ZEwks=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    desktop-file-utils
    nodejs
    npmHooks.npmConfigHook
    pkg-config
    protobuf
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapGAppsHook4
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    glib-networking
    webkitgtk_4_1
  ];

  env.OPENSSL_NO_VENDOR = true;

  doCheck = false;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Desktop application that turns documents into an interlinked LLM-maintained wiki";
    homepage = "https://github.com/nashsu/llm_wiki";
    changelog = "https://github.com/nashsu/llm_wiki/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "llm-wiki";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
})
