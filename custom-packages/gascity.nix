{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  tmux,
  git,
  jq,
  dolt,
  util-linux,
  nix-update-script,
}:

let
  releaseAsset =
    {
      x86_64-linux = {
        suffix = "linux_amd64";
        hash = "sha256-tpg/9RXTt3hcAKsbU5SP2uLMb27oi/wLYKfDvKcqt4s=";
      };
      aarch64-linux = {
        suffix = "linux_arm64";
        hash = "sha256-a+Qln84Rvu9X7R/BdJQDHZYCg2bLUHGusu1SM+FyxNw=";
      };
      x86_64-darwin = {
        suffix = "darwin_amd64";
        hash = "sha256-f0TD14Gh5oHjKofV4Sy7jwBWOPCF6zB8Z8t2CyZESnc=";
      };
      aarch64-darwin = {
        suffix = "darwin_arm64";
        hash = "sha256-dovvsnWmr/SoPpOHJhxqJ3LYxCDxwq5s2LnSM60wBa4=";
      };
    }
    .${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gascity";
  version = "1.1.0";

  src = fetchurl {
    url = "https://github.com/gastownhall/gascity/releases/download/v${finalAttrs.version}/gascity_${finalAttrs.version}_${releaseAsset.suffix}.tar.gz";
    hash = releaseAsset.hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 gc "$out/bin/gc"
    ln -s gc "$out/bin/gascity"
    ln -s gc "$out/bin/gas-city"

    install -Dm644 README.md "$out/share/doc/gascity/README.md"
    install -Dm644 CHANGELOG.md "$out/share/doc/gascity/CHANGELOG.md"
    install -Dm644 LICENSE "$out/share/licenses/gascity/LICENSE"

    runHook postInstall
  '';

  postInstall = ''
    "$out/bin/gc" completion bash > gc.bash
    "$out/bin/gc" completion zsh > _gc
    "$out/bin/gc" completion fish > gc.fish

    installShellCompletion --cmd gc \
      --bash gc.bash \
      --zsh _gc \
      --fish gc.fish
  '';

  passthru = {
    # Upstream also requires the Beads CLI (`bd`). This list intentionally
    # contains only the runtime dependencies this repo manages by default;
    # the Home Manager module can add Beads or rely on a profile-installed `bd`.
    runtimeDependencies = [
      tmux
      git
      jq
      dolt
      util-linux
    ];

    updateScript = nix-update-script {
      extraArgs = [
        "--use-github-releases"
        "--version-regex=^v(.*)$"
      ];
    };
  };

  meta = {
    description = "Orchestration-builder SDK for multi-agent coding workflows";
    homepage = "https://github.com/gastownhall/gascity";
    changelog = "https://github.com/gastownhall/gascity/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "gc";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
