pkgs: pkgsSuper:
let
  inherit (pkgs) callPackage lib;

  ulypkgsPackages = {

    ### Meta

    inherit ulypkgsPackages;

    listing = callPackage ./listing.nix { };

    update = callPackage ./update.nix { };

    ### Build support

    # postInstall
    copyIcons = callPackage ./copyIcons { };

    # preInstall
    copyInstallHook = callPackage ./copyInstallHook { };

    # preFixup (useless files) & postFixup (empty dirs)
    deleteUselessFiles = callPackage ./deleteUselessFiles { };

    fetchGoogleDrive = callPackage ./fetchGoogleDrive { };

    fetchMediaFire = callPackage ./fetchMediaFire { };

    fetchMega = callPackage ./fetchMega { };

    fetchWebIcon = callPackage ./fetchWebIcon { };

    # buildPhase
    renpyBuildHook = callPackage ./renpyBuildHook { };
    renpy7BuildHook = pkgs.renpyBuildHook.override { renpy = pkgs.renpy_7; };

    # postFixup
    renpyPackHook = callPackage ./renpyPackHook { };

    # postUnpack
    renpyUnpackHook = callPackage ./renpyUnpackHook { };

    # postInstall & preFixup (delete executables)
    renpyWrapHook = callPackage ./renpyWrapHook { };
    renpy7WrapHook = pkgs.renpyWrapHook.override {
      targetPackages = pkgs.targetPackages // {
        renpy = pkgs.targetPackages.renpy_7;
      };
    };

    # postBuild
    shrinkAssets = callPackage ./shrinkAssets { };

    ### Development

    # https://github.com/NixOS/nixpkgs/pull/504002
    renpy = callPackage ./renpy { };

    renpy_7 = callPackage ./renpy_7 { };

    ### Applications

    # testing purpose
    hello = pkgsSuper.hello.overrideAttrs (attrsSuper: {
      postPatch = ''
        ${attrsSuper.postPatch or ""}
        substituteInPlace src/hello.c tests/{hello,traditional}-1 --replace-fail world ulypkgs
      '';
    });

    # https://github.com/NixOS/nixpkgs/pull/504249
    rpatool = with pkgs.python3Packages; toPythonApplication rpatool;

    ### Games

    once-in-a-lifetime = callPackage ./once-in-a-lifetime { };

    summertime-saga = callPackage ./summertime-saga { };
  };

  pkgsOverridden = {
    pythonPackagesExtensions = pkgsSuper.pythonPackagesExtensions ++ [ (import ./python/packages.nix) ];

    python2 =
      (pkgsSuper.python2.override {
        self = pkgsOverridden.python2;
        packageOverrides = import ./python2/packages.nix;
      }).overrideAttrs
        (attrsSuper: {
          meta = attrsSuper.meta // {
            mainProgram = "python";
          };
        });
    python2Packages = pkgsOverridden.python2.pkgs;
  };
in
ulypkgsPackages // pkgsOverridden
