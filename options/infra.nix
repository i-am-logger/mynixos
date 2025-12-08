{ lib, ... }:

{
  infra = lib.mkOption {
    description = "Infrastructure services";
    default = { };
    type = lib.types.submodule {
      options = {
        k3s = lib.mkOption {
          description = "k3s Kubernetes cluster configuration";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "k3s Kubernetes cluster";

              role = lib.mkOption {
                type = lib.types.enum [ "server" "agent" ];
                default = "server";
                description = "k3s role - server or agent";
              };

              disableTraefik = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Disable built-in Traefik ingress controller";
              };

              apiPort = lib.mkOption {
                type = lib.types.port;
                default = 6443;
                description = "k3s API server port";
              };

              kubeconfigReadable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Make kubeconfig readable by non-root users";
              };
            };
          };
        };

        github-runner = lib.mkOption {
          description = "GitHub Actions Runner Controller stack (requires k3s)";
          default = { };
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "GitHub Actions runners with k3s and ARC";

              enableGpu = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable GPU passthrough to runners (vendor auto-detected from hardware)";
              };

              useCustomImage = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Use custom GitHub runner image from GHCR";
              };

              repositories = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "List of repository names to create runner sets for";
              };
            };
          };
        };
      };
    };
  };
}
