{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  cargo-tauri,
  fetchPnpmDeps,
  glib-networking,
  jq,
  moreutils,
  nodejs,
  openssl,
  pkg-config,
  pnpm_9,
  pnpmConfigHook,
  libsoup_3,
  webkitgtk_4_1,
  wrapGAppsHook4,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "marker";
  # Using the version from a PR that updated the deps, because otherwise they were too old to really be buildable.
  # PR link: https://github.com/tk04/Marker/pull/41
  version = "1.4.1-pr41";

  src = fetchFromGitHub {
    owner = "tk04";
    repo = "Marker";
    rev = "26f0849b969f99bf7f0bd9bd3ef18b417d24d382";
    hash = "sha256-3oqlIfvXPU62riLBHvRhsEZOFk8QRGgLVoTKnjnjDOA=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-M+95b50R3jwVd9nGy7qi1U+oJm5TIEwk1FXW4jiwqv4=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_9;
    fetcherVersion = 3;
    hash = "sha256-PzFt1uLuStGUHQbBk3jvYptCepM5Q0hW95NCq7mtlac=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    jq
    moreutils
    nodejs
    pkg-config
    pnpmConfigHook
    pnpm_9
    wrapGAppsHook4
  ];

  buildInputs = [
    glib-networking
    libsoup_3
    openssl
    webkitgtk_4_1
  ];

  postPatch = ''
    jq \
      '.plugins.updater.endpoints = [ ] | .bundle.createUpdaterArtifacts = false' \
      src-tauri/tauri.conf.json \
      | sponge src-tauri/tauri.conf.json
  '';

  meta = {
    description = "Desktop app for viewing and editing Markdown files";
    homepage = "https://github.com/tk04/Marker";
    changelog = "https://github.com/tk04/Marker/pull/41";
    license = lib.licenses.mit;
    mainProgram = "marker";
    platforms = lib.platforms.linux;
  };
})
