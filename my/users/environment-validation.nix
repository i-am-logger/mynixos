{ config, lib, ... }:

let
  envUtils = import ../../lib/environment-utils.nix { inherit lib; };
in
{
  config = {
    assertions = envUtils.mkEnvironmentAssertions config;
  };
}
