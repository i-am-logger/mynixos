{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.infra.k3s;
in
{
  config = mkIf cfg.enable {
    # Enable k3s
    services.k3s = {
      enable = true;
      inherit (cfg) role;
      extraFlags = toString (
        optionals cfg.disableTraefik [ "--disable=traefik" ]
      );
    };

    # Install essential k8s tools, set KUBECONFIG, and prevent NetworkManager from managing k3s interfaces
    environment = {
      systemPackages = with pkgs; [
        kubectl
        kubernetes-helm
        k3s
      ];

      variables = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };

      etc."NetworkManager/conf.d/k3s-unmanaged.conf".text = ''
        [keyfile]
        unmanaged-devices=interface-name:cni*;interface-name:flannel*;interface-name:veth*
      '';
    };

    # Open API port and trust k3s network interfaces
    networking.firewall = {
      allowedTCPPorts = [ cfg.apiPort ];
      trustedInterfaces = [ "cni0" "flannel.1" ];
    };

    # Make kubeconfig readable by users
    systemd.services.k3s-kubeconfig-permissions = mkIf cfg.kubeconfigReadable {
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
  };
}
