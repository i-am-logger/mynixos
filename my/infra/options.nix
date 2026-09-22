{ lib, ... }:

{
  infra = lib.mkOption {
    description = "Infrastructure services";
    default = { };
    type = lib.types.submodule {
      options = {
        # The cluster is my.infra.rke2, declared in my/infra/rke2/options.nix.
        # `my.infra.k3s` was removed with its module: it could express neither a
        # server address nor a token (so `role = "agent"` was unimplementable),
        # contributed no persistence, chmod 644'd the admin kubeconfig from a
        # oneshot driven by an option that DEFAULTED TO TRUE, opened the API port
        # on every interface, and hardcoded one CNI's interface names as trusted.
        # See docs/k8s-fleet-decision.md, "Disposition of the existing modules".
        github-runner = lib.mkOption {
          description = "GitHub Actions Runner Controller stack, deployed into my.infra.rke2";
          default = { };
          type = lib.types.submodule {
            options = {
              # The runner is a WORKLOAD. It asserts that my.infra.rke2 is
              # enabled and in the server role rather than standing up a cluster
              # of its own, so a host says both or neither.
              enable = lib.mkEnableOption "GitHub Actions runners (ARC) on the RKE2 cluster";

              enableGpu = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Have the runner container request a GPU, by the resource name
                  its vendor's device plugin advertises (the vendor is read from
                  my.hardware.gpu). ADVERTISING that resource is a cluster-wide
                  device plugin's job, and therefore not this module's.
                '';
              };

              useCustomImage = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Use custom GitHub runner image from GHCR";
              };

              repositories = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Repository names to create runner sets for, owned by the same
                  account whose PAT drives the stack. Per-user repositories are
                  named in my.users.<name>.github.repositories instead, and each
                  carries its own owner.
                '';
              };
            };
          };
        };
      };
    };
  };
}
