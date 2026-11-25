# A USB device by identity: vendor and product id, four lowercase hex digits
# each -- what `lsusb` prints and what udev's ATTRS{idVendor}/{idProduct}
# compare against (case-sensitively). Written "vvvv:pppp" or as an attrset.
#
# The shared type for anything that names a USB device: VM passthrough today;
# the peripheral modules' hand-written udev rules are meant to move onto it.
{ lib }:

let
  hex4 = lib.types.strMatching "[0-9a-f]{4}";

  device = lib.types.submodule {
    options = {
      vendor = lib.mkOption {
        type = hex4;
        example = "413c";
        description = "USB vendor id (idVendor), four lowercase hex digits.";
      };
      product = lib.mkOption {
        type = hex4;
        example = "a503";
        description = "USB product id (idProduct), four lowercase hex digits.";
      };
    };
  };
in
lib.types.coercedTo
  (lib.types.strMatching "[0-9a-f]{4}:[0-9a-f]{4}")
  (s:
  let parts = lib.splitString ":" s; in
  { vendor = builtins.elemAt parts 0; product = builtins.elemAt parts 1; })
  device
