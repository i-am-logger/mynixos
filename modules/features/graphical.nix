{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.graphical;

  # Stable version details for warp-terminal
  warp-latest-version = "0.2025.09.03.08.11.stable_03";
  warp-latest-hash = "sha256-V1eDS7SQf4oJLiW9OroT9QKPryQWutXhILAlb7124ks=";

  # Create a properly configured warp-terminal derivation
  warp-terminal-stable = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "warp-terminal";
    version = warp-latest-version;

    src = pkgs.fetchurl {
      url = "https://releases.warp.dev/stable/v${warp-latest-version}/warp-terminal-v${warp-latest-version}-1-${
        if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then "x86_64" else "aarch64"
      }.pkg.tar.zst";
      hash = warp-latest-hash;
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      zstd
      makeWrapper
    ];

    buildInputs = with pkgs; [
      alsa-lib
      brotli
      bzip2
      curl
      expat
      fontconfig
      freetype
      glibc
      keyutils
      krb5
      libglvnd
      libpng
      libpsl
      libssh2
      libunistring
      libxkbcommon
      nghttp2
      openssl
      vulkan-loader
      wayland
      wayland-protocols
      libdrm
      mesa
      xdg-utils
      xorg.libX11
      xorg.libxcb
      xorg.libXcursor
      xorg.libXi
      zlib
      (lib.getLib stdenv.cc.cc) # libstdc++.so and libgcc_s.so
    ];

    runtimeDependencies = with pkgs; [
      libglvnd
      libxkbcommon
      vulkan-loader
      wayland
      wayland-protocols
      libdrm
      mesa
      pipewire
      xdg-desktop-portal-wlr
      xdg-utils
      xorg.libX11
      xorg.libxcb
      xorg.libXcursor
      xorg.libXi
    ];

    sourceRoot = ".";

    dontBuild = true;
    dontConfigure = true;

    unpackPhase = ''
      runHook preUnpack
      tar xf $src
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/opt
      cp -r opt/warpdotdev $out/opt/
      cp -r usr/bin/warp-terminal $out/bin/
      if [ -d usr/share ]; then
        cp -r usr/share $out/share
      fi

      # Patch the executable to point to the correct location
      substituteInPlace $out/bin/warp-terminal \
        --replace "/opt/warpdotdev" "$out/opt/warpdotdev"
      # Wrap the binary with required environment
      wrapProgram $out/bin/warp-terminal \
        --set WARP_ENABLE_WAYLAND 1 \
        --set WGPU_BACKEND gl \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.runtimeDependencies}"
    '';

    meta = {
      description = "Rust-based terminal (Stable version)";
      homepage = "https://www.warp.dev";
      license = lib.licenses.unfree;
      maintainers = with lib.maintainers; [ ];
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
  });

  # Preview version details for warp-terminal
  warp_preview_version = "0.2025.11.06.20.04.preview_01";
  warp_preview_hash = "sha256-FvNExniCGC87M22oZicc+gkF66swEWb6ROxDrW4pUus=";

  warp-terminal-preview-fn =
    { lib
    , stdenv
    , fetchurl
    , autoPatchelfHook
    , zstd
    , alsa-lib
    , curl
    , fontconfig
    , libglvnd
    , libxkbcommon
    , vulkan-loader
    , wayland
    , waylandProtocols
    , libdrm
    , mesa
    , pipewire
    , xdgDesktopPortalWlr
    , xdg-utils
    , xorg
    , zlib
    , makeWrapper
    , waylandSupport ? true
    ,
    }:

    let
      pname = "warp-terminal-preview";
      version = warp_preview_version;

      # Determine architecture
      linux_arch = if stdenv.hostPlatform.system == "x86_64-linux" then "x86_64" else "aarch64";
    in
    stdenv.mkDerivation (finalAttrs: {
      inherit pname version;

      src = fetchurl {
        url = "https://releases.warp.dev/preview/v${version}/warp-terminal-preview-v${version}-1-${linux_arch}.pkg.tar.zst";
        hash = warp_preview_hash;
      };

      sourceRoot = ".";

      postPatch = ''
        substituteInPlace usr/bin/warp-terminal-preview \
          --replace-fail /opt/ $out/opt/
      '';

      nativeBuildInputs = [
        autoPatchelfHook
        zstd
        makeWrapper
      ];

      # Add a debug message to the build
      preBuild = ''
        echo "Building warp-terminal-preview with Wayland support"
        echo "Using waylandProtocols from arguments"
      '';

      buildInputs = [
        alsa-lib # libasound.so.2
        curl
        fontconfig
        (lib.getLib stdenv.cc.cc) # libstdc++.so libgcc_s.so
        zlib
        # Wayland dependencies
        wayland
        waylandProtocols
        libdrm
        mesa
      ];

      runtimeDependencies = [
        libglvnd # for libegl
        libxkbcommon
        stdenv.cc.libc
        vulkan-loader
        xdg-utils
        xorg.libX11
        xorg.libxcb
        xorg.libXcursor
        xorg.libXi
        # Wayland dependencies
        wayland
        waylandProtocols
        libdrm
        mesa
        pipewire
        xdgDesktopPortalWlr
      ];

      installPhase = ''
        runHook preInstall

        mkdir $out
        cp -r opt usr/* $out

        ${lib.optionalString waylandSupport ''
          wrapProgram $out/bin/warp-terminal-preview \
            --set WARP_ENABLE_WAYLAND 1 \
            --set WGPU_BACKEND gl
        ''}

        runHook postInstall
      '';

      # Use the same meta information as the stable package
      meta = {
        description = "Rust-based terminal (Preview version)";
        homepage = "https://www.warp.dev";
        license = lib.licenses.unfree;
        maintainers = with lib.maintainers; [ ];
        platforms = [
          "x86_64-linux"
          "aarch64-linux"
        ];
      };
    });

  # Create warp-terminal-preview package
  warp-terminal-preview = pkgs.callPackage warp-terminal-preview-fn {
    waylandSupport = true;
    waylandProtocols = pkgs.wayland-protocols;
    libdrm = pkgs.libdrm;
    mesa = pkgs.mesa;
    pipewire = pkgs.pipewire;
    xdgDesktopPortalWlr = pkgs.xdg-desktop-portal-wlr;
    xdg-utils = pkgs.xdg-utils;
  };
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base desktop configuration
    {
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (pkg.pname or pkg.name) [
          "warp-terminal"
          "warp-terminal-preview"
          "vscode"
          "vscode-with-extensions"
        ];
    }

    # Warp terminal stable
    (mkIf cfg.warp.enable {
      environment.systemPackages = [
        warp-terminal-stable
      ];

      environment.sessionVariables = {
        WARP_ENABLE_WAYLAND = lib.mkForce 1;
      };
    })

    # Warp terminal preview
    (mkIf cfg.warp.preview {
      environment.systemPackages = [
        warp-terminal-preview
        pkgs.gh # GitHub CLI for auth token
        pkgs.docker # Required for the Docker-based MCP server
      ];
    })

    # VSCode configuration
    (mkIf cfg.vscode.enable {
      environment.systemPackages = with pkgs; [
        libsecret # For keyring integration
        libxkbcommon
      ];
    })

    # Browser configuration
    (mkIf cfg.browser.enable {
      programs.chromium = {
        enable = true;
        extensions = [
          "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password extension
        ];
      };
    })

    # Audio tools
    (mkIf cfg.audioTools.enable {
      environment.systemPackages = with pkgs; [
        alsa-utils # ALSA utilities (amixer, alsamixer, etc.)
        pavucontrol # PulseAudio/PipeWire GUI volume control
        pulseaudio # PulseAudio utilities
      ];
    })
  ]);
}
