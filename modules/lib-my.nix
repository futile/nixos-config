let
  mkEditorTools = import ./editor-tools.nix;

  # reference: https://discourse.nixos.org/t/wrapping-packages/4431
  mkWrappedWithDeps =
    final: prev:
    {
      pkg,
      pathsToWrap,
      prefix-deps ? [ ],
      suffix-deps ? [ ],
      extraWrapProgramArgs ? [ ],
      otherArgs ? { },
    }:
    let
      prefixBinPath = prev.lib.makeBinPath prefix-deps;
      suffixBinPath = prev.lib.makeBinPath suffix-deps;
    in
    prev.symlinkJoin (
      {
        name = pkg.name + "-wrapped";
        pname = pkg.pname or pkg.name;
        paths = [ pkg ];
        buildInputs = [ final.makeWrapper ];
        postBuild = ''
          cd "$out"
          for p in ${builtins.toString pathsToWrap}
          do
            wrapProgram "$out/$p" \
              --prefix PATH : "${prefixBinPath}" \
              --suffix PATH : "${suffixBinPath}" \
              ${builtins.toString extraWrapProgramArgs}
          done
        '';
      }
      // otherArgs
    );

  # Newest linuxPackages_X_Y whose ZFS kernel module isn't marked broken.
  # reference: https://wiki.nixos.org/wiki/ZFS
  latestZfsCompatibleKernelPackages =
    final: zfsPackage:
    let
      lib = final.lib;
      attr = zfsPackage.kernelModuleAttribute;
      compatible = lib.filterAttrs (
        name: kp:
        builtins.match "linux_[0-9]+_[0-9]+" name != null
        && (builtins.tryEval kp).success
        && !kp.${attr}.meta.broken
      ) final.linuxKernel.packages;
    in
    lib.last (
      lib.sort (a: b: lib.versionOlder a.kernel.version b.kernel.version) (builtins.attrValues compatible)
    );

  lib-my-overlay = final: prev: {
    lib = prev.lib // {
      my = {
        editorTools = mkEditorTools final;
        mkWrappedWithDeps = mkWrappedWithDeps final prev;
        latestZfsCompatibleKernelPackages = latestZfsCompatibleKernelPackages final;
      };
    };
  };
in
{
  nixpkgs.overlays = [ lib-my-overlay ];
}
