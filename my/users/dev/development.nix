{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable dev tools when any user has dev = true
  anyUserDev = any (userCfg: userCfg.dev or false) (attrValues config.my.users);

  # Get list of all user names
  userNames = attrNames config.my.users;

  # Auto-enable Docker infrastructure when any user has dev = true
  dockerCfg = config.my.infra.docker;
in
{
  config = mkIf anyUserDev (mkMerge [
    # Base development groups
    {
      # Add users to development-related groups
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "disk" "dialout" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);
    }

    # Docker support (auto-enabled by user dev feature)
    (mkIf (dockerCfg.enable or anyUserDev) {
      # Auto-enable Docker infrastructure
      my.infra.docker.enable = mkDefault true;
      environment.systemPackages = with pkgs; [
        docker-compose
        minikube
        runc
        lazydocker
      ];

      # Add all users to docker group
      users.groups.docker.members = userNames;

      # Also add created users to docker group
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "docker" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);

      virtualisation.docker = {
        enable = true;
        enableOnBoot = false;
        rootless = {
          enable = true;
          setSocketVariable = true;
        };
      };
    })

    # Binfmt emulation support
    (mkIf cfg.binfmt.enable {
      boot.binfmt = {
        emulatedSystems = [ "aarch64-linux" ];
      };
    })

    # AppImage support (now under binfmt)
    (mkIf cfg.binfmt.appimage {
      boot.binfmt.registrations.appimage = {
        wrapInterpreterInShell = false;
        interpreter = "${pkgs.appimage-run}/bin/appimage-run";
        recognitionType = "magic";
        offset = 0;
        mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
        magicOrExtension = ''\x7fELF....AI\x02'';
      };
    })

    # k3s Kubernetes cluster for local development
    (mkIf cfg.k3s.enable {
      # Enable k3s
      services.k3s = {
        enable = true;
        role = cfg.k3s.role;
        extraFlags = toString (
          optionals cfg.k3s.disableTraefik [ "--disable=traefik" ]
        );
      };

      # Install essential k8s tools
      environment.systemPackages = with pkgs; [
        kubectl
        kubernetes-helm
        k3s
      ];

      # Set KUBECONFIG environment variable system-wide
      environment.variables = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };

      # Open API port and trust k3s network interfaces
      networking.firewall = {
        allowedTCPPorts = [ cfg.k3s.apiPort ];
        trustedInterfaces = [ "cni0" "flannel.1" ];
      };

      # Make kubeconfig readable by users
      systemd.services.k3s-kubeconfig-permissions = mkIf cfg.k3s.kubeconfigReadable {
        description = "Set k3s kubeconfig permissions";
        after = [ "k3s.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
            sleep 1
          done
          chmod 644 /etc/rancher/k3s/k3s.yaml
        '';
      };

      # Prevent NetworkManager from managing k3s interfaces
      environment.etc."NetworkManager/conf.d/k3s-unmanaged.conf".text = ''
        [keyfile]
        unmanaged-devices=interface-name:cni*;interface-name:flannel*;interface-name:veth*
      '';
    })
  ]);
}
