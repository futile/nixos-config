{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  writeShellApplication,
  curl,
  tmux,
  git,
  jq,
  dolt,
  util-linux,
  nix,
  gnused,
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
        hash = "sha256-a+Qln84RvudX7R/BdJQDHZYCSLbLUHGusu1SM+FyxNw=";
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

    updateScript = lib.getExe (writeShellApplication {
      name = "gascity-update-script";
      runtimeInputs = [
        curl
        jq
        nix
        gnused
      ];
      text = ''
        set -euo pipefail

        file="''${UPDATE_NIX_FILE:-custom-packages/gascity.nix}"
        if [[ ! -f "$file" && -f gascity.nix ]]; then
          file=gascity.nix
        fi
        if [[ ! -f "$file" ]]; then
          echo "gascity update: could not find package file: $file" >&2
          exit 1
        fi

        release_json=$(curl -fsSL "https://api.github.com/repos/gastownhall/gascity/releases/latest")
        version=$(jq -er '.tag_name | sub("^v"; "")' <<< "$release_json")

        asset_hash() {
          local suffix="$1"
          local digest
          digest=$(jq -er --arg name "gascity_''${version}_''${suffix}.tar.gz" '
            .assets[]
            | select(.name == $name)
            | .digest
            | sub("^sha256:"; "")
          ' <<< "$release_json")
          nix hash convert --hash-algo sha256 --to sri "$digest"
        }

        replace_platform_hash() {
          local system="$1"
          local hash="$2"
          sed -i -E "/''${system} = \\{/,/\\};/ s|(hash = )\"sha256-[^\"]+\";|\\1\"''${hash}\";|" "$file"
        }

        linux_amd64=$(asset_hash linux_amd64)
        linux_arm64=$(asset_hash linux_arm64)
        darwin_amd64=$(asset_hash darwin_amd64)
        darwin_arm64=$(asset_hash darwin_arm64)

        sed -i -E 's|(version = )"[^"]+";|\1"'"$version"'";|' "$file"
        replace_platform_hash x86_64-linux "$linux_amd64"
        replace_platform_hash aarch64-linux "$linux_arm64"
        replace_platform_hash x86_64-darwin "$darwin_amd64"
        replace_platform_hash aarch64-darwin "$darwin_arm64"
      '';
    });
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
