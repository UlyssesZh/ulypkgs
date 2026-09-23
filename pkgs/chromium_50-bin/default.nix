{
  lib,
  stdenv,
  stdenvNoCC,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  python3,
  versionCheckHook,
  alsa-lib,
  atk,
  cairo,
  cups,
  copyDesktopItems,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk2,
  harfbuzz,
  libGL,
  libX11,
  libXScrnSaver,
  libXcomposite,
  libXcursor,
  libXdamage,
  libexif,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  makeDesktopItem,
  nspr,
  nss,
  pango,
  udev,
  copyIcons,
  deleteUselessFiles,
  resizeIcons,
}:

let
  # The continuous builds of the Chromium project are the only prebuilt Linux
  # binaries of Chromium 50 that Chromium itself publishes.  The 50.0.2661
  # branch was cut from the main branch at revision 378081, so revision 378072 is
  # the newest continuous build whose version is 50.0.2661.
  revision = "378072";

  # Chromium 50 links against GConf, which nixpkgs does not provide anymore.
  # See ./gconf-shim.c for why a shim with the semantics of an unconfigured GConf
  # is enough for Chromium 50 to work.
  gconfShim = stdenv.mkDerivation {
    pname = "libgconf-2-shim";
    version = "0.1.0";

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib
      $CC -shared -fPIC -Wl,-soname,libgconf-2.so.4 -o $out/lib/libgconf-2.so.4 ${./gconf-shim.c}

      runHook postInstall
    '';

    meta = {
      description = "Stand-in for the GConf client library, which reports that no setting is configured";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ulysseszhan ];
      platforms = lib.platforms.linux;
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chromium-bin";
  version = "50.0.2661.0";

  src = fetchzip {
    url = "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/${revision}/chrome-linux.zip";
    hash = "sha256-Pcu/ESLU6C3A7e841ZWhNuyi/KAAv+dJ8ODq0Wk+pkI=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    python3
    copyDesktopItems
    copyIcons
    resizeIcons
    deleteUselessFiles
  ];

  buildInputs = [
    alsa-lib
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gconfShim
    gdk-pixbuf
    glib
    gtk2
    libGL
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    nspr
    nss
    pango
    stdenv.cc.cc.lib
  ];

  # Chromium 50 loads these with dlopen, so they have to be in its rpath even
  # though none of its binaries links against them
  runtimeDependencies = [
    libGL
    (lib.getLib libexif)
    (lib.getLib udev)
  ];

  # the executables and the data files have to stay in the same directory,
  # because the binaries look for resources relative to themselves
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/chromium-50
    cp -r . $out/lib/chromium-50

    # fetchzip does not preserve the permissions of the archive
    find $out/lib/chromium-50 -type d -exec chmod 755 {} +
    find $out/lib/chromium-50 -type f -exec chmod 644 {} +
    chmod 755 $out/lib/chromium-50/{chrome,chrome_sandbox,chrome-wrapper,nacl_helper,nacl_helper_bootstrap,nacl_helper_nonsfi,xdg-mime,xdg-settings}

    install -Dm644 $out/lib/chromium-50/chrome.1 $out/share/man/man1/chromium.1

    runHook postInstall
  '';

  postInstall = ''
    # Chromium 50 shares ~/.config/chromium with current versions of Chromium by
    # default, and it refuses to run with a profile that a newer version wrote,
    # so a version specific profile is used unless the command line specifies
    # another one (Chromium uses the last occurrence of a switch).
    #
    # The setuid sandbox of Chromium 50 needs its sandbox helper to be setuid
    # root, which is impossible in the store, and Chromium refuses to start
    # without a sandbox, so it is asked to use its namespace sandbox instead.
    #
    # The seccomp-bpf policy of Chromium 50 is from 2016 and kills its renderer
    # processes on current systems, where the C library performs system calls
    # that did not exist back then, so the seccomp filter is disabled as well.
    # The namespace sandbox remains in effect: the renderer processes run in
    # their own user, pid and network namespaces.
    makeWrapper $out/lib/chromium-50/chrome $out/bin/chromium \
      --prefix LD_LIBRARY_PATH : $out/lib/chromium-50 \
      --set CHROME_DESKTOP chromium_50-bin.desktop \
      --add-flags '--disable-setuid-sandbox --disable-seccomp-filter-sandbox' \
      --add-flags '--user-data-dir="''${XDG_CONFIG_HOME:-$HOME/.config}/chromium-50-bin"'
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  # Chromium 50 statically links harfbuzz and exports its symbols.  The dynamic
  # linker prefers the symbols of the executable over those of the libraries it
  # loads, so the harfbuzz that pango, which the GTK 2 user interface of Chromium
  # 50 uses, resolves its calls to would be the harfbuzz inside Chromium 50, whose
  # internal ABI is different, which crashes the browser as soon as GTK shapes
  # text.  Hiding those symbols makes pango use the harfbuzz it was built
  # against.  This has to happen after autoPatchelfHook has patched the binaries,
  # hence a post phase instead of postFixup.
  #
  # The other symbols that Chromium 50 exports and that its libraries also export
  # are the allocator functions, which Chromium overrides deliberately and whose
  # ABI does not change, so they are left alone.
  postPhases = [ "hideSymbolsPhase" ];

  hideSymbolsPhase = ''
    runHook preHideSymbols

    python3 ${./hide-symbols.py} ${lib.getLib harfbuzz}/lib/libharfbuzz.so.0 \
      $out/lib/chromium-50/chrome \
      $out/lib/chromium-50/nacl_helper

    runHook postHideSymbols
  '';

  # the icon shipped in the archive is the only Chromium 50 icon available
  icon = "product_logo_48.png";

  desktopItems = [
    (makeDesktopItem {
      name = "chromium_50-bin";
      desktopName = "Chromium 50";
      comment = finalAttrs.meta.description;
      exec = "${finalAttrs.meta.mainProgram} %U";
      icon = "chromium_50-bin";
      categories = [
        "Network"
        "WebBrowser"
      ];
      startupNotify = true;
    })
  ];

  meta = {
    description = "Web browser from the Chromium project, version 50 (prebuilt binary)";
    longDescription = ''
      Chromium is an open source web browser.  This package provides version 50,
      which was released in 2016, as built by the continuous build of the
      Chromium project, so that content and web applications of that era can
      still be run.  Since it is a prebuilt binary, it is not built against the
      libraries in nixpkgs.

      $out/bin/chromium runs the browser with its setuid sandbox and its
      seccomp-bpf filter disabled, because the former needs a setuid root helper
      that the store cannot provide and the latter kills the renderer processes
      on current systems; the namespace sandbox is still in effect.  Use
      $out/lib/chromium-50/chrome directly to run the browser without these
      switches, and the --no-sandbox switch to disable the sandbox completely.

      The archive contains unstripped binaries, so the package is larger than a
      stripped build of the same browser would be.
    '';
    homepage = "https://www.chromium.org/";
    downloadPage = "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/${revision}/";
    changelog = "https://chromium.googlesource.com/chromium/src/+log/refs/branch-heads/2661";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ulysseszhan ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "chromium";
  };
})
