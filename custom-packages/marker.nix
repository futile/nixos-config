{
  lib,
  rustPlatform,
  stdenv,
  fetchFromGitHub,
  cargo-tauri_1,
  fetchPnpmDeps,
  glib-networking,
  gtk3,
  jq,
  libsoup_2_4,
  moreutils,
  nodejs,
  openssl,
  perl,
  pkg-config,
  pnpm_9,
  pnpmConfigHook,
  webkitgtk_4_1,
  wrapGAppsHook3,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "marker";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "tk04";
    repo = "Marker";
    rev = "f4f6ebcb973ee2daabb3afaf3d8ab80b00783460";
    hash = "sha256-1lPW0mgkHhuFrqAFvrtKXgMiSUv3fkLBimDmHk7h57I=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_9;
    fetcherVersion = 1;
    hash = "sha256-usNrLpR5UVOac1zQ2v1w6VmxnbJ+SURDNugykygzT5M=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-uISJT0vmv60U66vUxOUpGXgGlAFJlGH0KRQyGUF+VNY=";

  # Upstream enables `native-tls-vendored`, which tries to build OpenSSL from source.
  # That path failed here because the vendored OpenSSL build expects extra tooling and
  # is unnecessary in Nix, so force the crate graph to use nixpkgs' OpenSSL instead.
  env.OPENSSL_NO_VENDOR = 1;

  nativeBuildInputs = [
    cargo-tauri_1.hook
    jq
    moreutils
    nodejs
    perl
    pkg-config
    pnpmConfigHook
    pnpm_9
    wrapGAppsHook3
  ];

  buildInputs = [
    glib-networking
    gtk3
    # Marker is still on Tauri 1 on Linux, which pulls the old soup2 WebKit stack.
    # This nixpkgs revision marks libsoup_2_4 insecure, but it is still required to
    # build and link the app successfully.
    libsoup_2_4
    openssl
    # webkitgtk_4_0 has been removed from this nixpkgs snapshot. Marker's Tauri 1 stack
    # still expects the older 4.0 pkg-config and linker names, so we build against 4.1
    # and provide compatibility aliases below.
    webkitgtk_4_1
  ];

  postPatch = ''
    # `wry-0.24.7` no longer compiles cleanly against the toolchain in this nixpkgs
    # snapshot without importing `SettingsExt` explicitly in the GTK WebKit backend.
    # Patch the vendored dependency in place instead of carrying a larger fork.
    substituteInPlace "$cargoDepsCopy"/source-registry-0/wry-0.24.7/src/webview/webkitgtk/mod.rs \
      --replace-fail 'traits::*, LoadEvent, NavigationPolicyDecision, PolicyDecisionType, URIRequest,' \
      'traits::*, LoadEvent, NavigationPolicyDecision, PolicyDecisionType, SettingsExt, URIRequest,'

    # Disable the upstream updater during Nix builds. The app references GitHub release
    # metadata and signing config that are only useful for upstream release artifacts.
    jq \
      '.tauri.updater.active = false | .tauri.updater.endpoints = []' \
      src-tauri/tauri.conf.json \
      | sponge src-tauri/tauri.conf.json
  '';

  preConfigure = ''
    # Tauri 1 / webkit2gtk crates still ask pkg-config for the removed 4.0 names even
    # though this nixpkgs snapshot only ships the 4.1 WebKitGTK development files.
    # Provide local .pc aliases so the old pkg-config lookups resolve to the 4.1 stack.
    mkdir -p .pkg-config
    ln -s ${webkitgtk_4_1.dev}/lib/pkgconfig/javascriptcoregtk-4.1.pc .pkg-config/javascriptcoregtk-4.0.pc
    ln -s ${webkitgtk_4_1.dev}/lib/pkgconfig/webkit2gtk-4.1.pc .pkg-config/webkit2gtk-4.0.pc
    ln -s ${libsoup_2_4.dev}/lib/pkgconfig/libsoup-2.4.pc .pkg-config/libsoup-2.4.pc
    export PKG_CONFIG_PATH="$PWD/.pkg-config''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

    # The linker also still looks for the removed 4.0 sonames. Mirror those names to
    # the available 4.1 shared libraries so the final link step succeeds.
    mkdir -p .lib-compat
    ln -s ${webkitgtk_4_1}/lib/libjavascriptcoregtk-4.1.so .lib-compat/libjavascriptcoregtk-4.0.so
    ln -s ${webkitgtk_4_1}/lib/libwebkit2gtk-4.1.so .lib-compat/libwebkit2gtk-4.0.so
    export NIX_LDFLAGS="-L$PWD/.lib-compat ''${NIX_LDFLAGS-}"
  '';

  meta = {
    description = "Desktop app for viewing and editing Markdown files";
    homepage = "https://github.com/tk04/Marker";
    changelog = "https://github.com/tk04/Marker/releases/tag/master";
    license = lib.licenses.mit;
    mainProgram = "marker";
    platforms = lib.platforms.linux;
  };
})
