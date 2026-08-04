# Biometric authentication hardware (darwin)
#
# Declared here rather than in ../options.nix so the option does not exist on the
# other platform: setting it there fails with "The option `my.hardware.biometrics'
# does not exist" instead of silently doing nothing. `types.submodule`
# declarations for the same option merge, so this composes with the
# cross-platform `my.hardware` options.
{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        # Fingerprint / proximity unlock. Implemented per vendor, mirroring
        # bluetooth: the category carries the toggle, the vendor directory
        # carries the wiring (my/hardware/biometrics/apple).
        biometrics = lib.mkOption {
          description = "Biometric authentication hardware";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "biometric authentication";

              touchId = lib.mkOption {
                description = "Touch ID (Apple Secure Enclave fingerprint sensor)";
                default = { };
                type = lib.types.submodule {
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Authenticate sudo with Touch ID";
                    };

                    reattach = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = ''
                        Load pam_reattach, which reattaches sudo to the user's
                        bootstrap session.

                        Without it Touch ID silently does nothing inside a
                        terminal multiplexer and sudo falls back to a password.
                        Since mynixos defaults to zellij, that would be the
                        normal case rather than the edge case -- hence the
                        default of true.
                      '';
                    };
                  };
                };
              };

              watchId = lib.mkOption {
                description = "Apple Watch proximity unlock (pam_watchid)";
                default = { };
                type = lib.types.submodule {
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Authenticate sudo by Apple Watch";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
