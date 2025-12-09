{ lib, ... }:

{
  video = lib.mkOption {
    description = "Video device configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        virtual = lib.mkOption {
          description = "Virtual camera devices (v4l2loopback)";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable v4l2loopback kernel module for virtual webcam (auto-enabled by user streaming)";
              };
            };
          };
        };
      };
    };
  };
}
