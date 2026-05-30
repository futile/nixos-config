{
  lib,
  stdenv,
  applyPatches,
  makeWrapper,
  callPackage,
  python311,
  gtk3,
  gobject-introspection,
  libayatana-appindicator,
  wrapGAppsHook3,
  serenaInput,
  editorTools ? [ ],
}:

let
  pyproject-nix = serenaInput.inputs.pyproject-nix;
  pyproject-build-systems = serenaInput.inputs.pyproject-build-systems;
  uv2nix = serenaInput.inputs.uv2nix;

  patchedSerenaSrc = applyPatches {
    name = "serena-patched-source";
    src = serenaInput;
    patches = [
      ./patches/serena-rust-analyzer-initialization-options.patch
    ];
  };

  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = patchedSerenaSrc;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  python = python311;
  pyprojectHacks = callPackage pyproject-nix.build.hacks { };

  pyprojectOverrides =
    final: prev:
    {
      ruamel-yaml-clib = prev.ruamel-yaml-clib.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          final.setuptools
        ];
      });
      proxy-tools = prev.proxy-tools.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          final.setuptools
        ];
      });
      pywebview = prev.pywebview.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          final.setuptools
          final.setuptools-scm
        ];
      });
    }
    // lib.optionalAttrs stdenv.isLinux {
      pycairo = pyprojectHacks.nixpkgsPrebuilt {
        from = python.pkgs.pycairo;
        prev = {
          passthru = {
            dependencies = { };
            optional-dependencies = { };
            dependency-groups = { };
          };
        };
      };
      pygobject3 = pyprojectHacks.nixpkgsPrebuilt {
        from = python.pkgs.pygobject3;
        prev = {
          passthru = {
            dependencies = {
              pycairo = [ ];
            };
            optional-dependencies = { };
            dependency-groups = { };
          };
        };
      };
      pystray = prev.pystray.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          dependencies = (old.passthru.dependencies or { }) // {
            pygobject3 = [ ];
          };
        };
      });
    };

  pythonSet = (callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      overlay
      pyprojectOverrides
    ]
  );

  serenaEnv = pythonSet.mkVirtualEnv "serena-env" workspace.deps.default;

  serena = stdenv.mkDerivation {
    name = "serena";
    dontUnpack = true;
    dontWrapGApps = true;
    nativeBuildInputs = [
      makeWrapper
    ]
    ++ lib.optionals stdenv.isLinux [
      wrapGAppsHook3
      gobject-introspection
    ];
    buildInputs = lib.optionals stdenv.isLinux [
      gtk3
      libayatana-appindicator
    ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      ${lib.optionalString (!stdenv.isLinux) ''
        ln -s ${serenaEnv}/bin/serena $out/bin/serena
      ''}
      ln -s ${serenaEnv}/bin/serena-hooks $out/bin/serena-hooks

      runHook postInstall
    '';
    preFixup = lib.optionalString stdenv.isLinux ''
      makeWrapper ${serenaEnv}/bin/serena $out/bin/serena "''${gappsWrapperArgs[@]}"
    '';
    meta = {
      description = "Coding agent toolkit providing semantic retrieval and editing capabilities";
      homepage = "https://oraios.github.io/serena";
      changelog = "https://github.com/oraios/serena/blob/main/CHANGELOG.md";
      mainProgram = "serena";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  };
in
stdenv.mkDerivation {
  name = "serena-with-editor-tools";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    ln -s ${serena}/bin/serena-hooks $out/bin/serena-hooks
    makeWrapper ${serena}/bin/serena $out/bin/serena \
      --suffix PATH : ${lib.makeBinPath editorTools}

    runHook postInstall
  '';
  inherit (serena) meta;
}
