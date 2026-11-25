# Elgato Game Capture 4K X (0fd9:009b; 009c and 009d in its other USB speed
# modes).
#
# The video is plain UVC (uvcvideo; YUYV, NV12, P010 for 10-bit HDR, ...).
# Its vendor controls -- HDR tone mapping, EDID mode -- go over the same USB
# device through libusb, which needs the usbfs node read-write. That node is
# root:root 0664 by default, so tools like elgato4k-linux only ran with sudo;
# uaccess hands it to the logged-in seat user instead.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.hardware.peripherals.elgato.game-capture-4k-x;

  udevRules = pkgs.writeTextFile {
    name = "elgato-4k-x-udev-rules";
    destination = "/lib/udev/rules.d/70-elgato-4k-x.rules";
    text = ''
      # Elgato Game Capture 4K X: vendor control over usbfs for the seat user.
      # The card enumerates under a different product ID per USB speed mode.
      SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="009b|009c|009d", TAG+="uaccess"
    '';
  };

  # uvcvideo alone, from the running kernel's source plus the mailbox patch
  # (from elgato4k-linux, GPL). Installed under updates/, which depmod
  # searches before the in-tree kernel/ directory, so modprobe loads this
  # one; the rest of the kernel stays the cached build.
  kernel = config.boot.kernelPackages.kernel;
  uvcvideo = pkgs.stdenv.mkDerivation {
    pname = "uvcvideo-elgato-4k-x";
    inherit (kernel) version src;
    patches = [ ./uvcvideo-variable-xu.patch ];

    unpackPhase = ''
      mkdir source
      tar -xf $src -C source --strip-components=1 --wildcards '*/drivers/media/usb/uvc/*'
      cd source
    '';

    nativeBuildInputs = kernel.moduleBuildDependencies;
    makeFlags = config.boot.kernelPackages.kernelModuleMakeFlags ++ [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(PWD)/drivers/media/usb/uvc"
    ];
    buildFlags = [ "modules" ];

    installPhase = ''
      runHook preInstall
      install -Dm444 drivers/media/usb/uvc/uvcvideo.ko \
        $out/lib/modules/${kernel.modDirVersion}/updates/uvcvideo.ko
      runHook postInstall
    '';

    meta.platforms = lib.platforms.linux;
  };
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    { services.udev.packages = [ udevRules ]; }

    (lib.mkIf cfg.uvcvideo.patch {
      boot.extraModulePackages = [ uvcvideo ];
    })

    # In this host's HDMI chain: force the downstream monitor's EDID onto
    # the connector (the card reports no ELD), keep it enabled regardless of
    # hotplug, and keep HDMI audio pins up without a valid ELD.
    (lib.mkIf (cfg.passthrough.output != null) {
      boot.kernelParams = [
        "amdgpu.audio=1"
        "snd_hda_codec_hdmi.enable_all_pins=1"
        "snd_hda_codec_hdmi.static_hdmi_pcm=1"
        "drm.edid_firmware=${cfg.passthrough.output}:edid/${baseNameOf cfg.passthrough.edid}"
        "video=${cfg.passthrough.output}:e"
      ];

      hardware.firmware = [
        (pkgs.runCommand "elgato-4k-x-passthrough-edid" { } ''
          mkdir -p $out/lib/firmware/edid
          cp ${cfg.passthrough.edid} $out/lib/firmware/edid/${baseNameOf cfg.passthrough.edid}
        '')
      ];
    })
  ]);
}
