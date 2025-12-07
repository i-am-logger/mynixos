{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.infra.github-runner;

  # Collect all repositories from all users with github.username set
  userRepositories = lib.flatten (
    lib.mapAttrsToList (username: userCfg:
      let
        githubUser = userCfg.github.username or null;
      in
      lib.optionals (githubUser != null) (
        map (repo: {
          inherit repo username;
          githubUsername = githubUser;
        }) (userCfg.github.repositories or [])
      )
    ) config.my.users
  );

  # List of repositories to create runner sets for (combined from users and legacy cfg.repositories)
  repositories = (map (item: item.repo) userRepositories) ++ cfg.repositories;

  # Get first user's GitHub username (personal data from my.users)
  userNames = attrNames config.my.users;
  firstUser = if userNames != [ ] then head userNames else throw "No users configured in my.users";
  githubUsername =
    let
      firstUserCfg = config.my.users.${firstUser};
    in
    firstUserCfg.github.username or (throw "github.username not set for user ${firstUser}");

  # Auto-detect GPU vendor from mynixos hardware configuration
  autoGpuVendor = config.my.hardware.gpu or null;

  # Use first user as runner user (for pass command)
  autoRunnerUser = firstUser;

  hostname = config.networking.hostName;

  # Custom NixOS runner image from GHCR
  runnerImageName = "ghcr.io/${githubUsername}/github-runner:latest";

  # Generate runner set services for each repository
  mkRunnerSetService = repo: {
    name = "arc-runner-set-${repo}";
    value = {
      description = "Deploy GitHub Actions Runner Scale Set for ${repo}";
      after = [ "arc-setup.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = "/persist/etc/github-runner-token";
      };

      script = ''
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

        # Wait for ARC controller
        until ${pkgs.kubectl}/bin/kubectl get namespace arc-systems; do
          echo "Waiting for ARC controller..."
          sleep 5
        done

        # Additional wait for controller to be fully ready
        sleep 10

        if [ -z "$GITHUB_TOKEN" ]; then
          echo "Error: GITHUB_TOKEN not found in environment file"
          exit 1
        fi

        # Install runner scale set for ${repo} - repo-level registration
        # Using dind mode (requires SidecarContainers feature gate enabled in k3s)
        ${pkgs.kubernetes-helm}/bin/helm upgrade --install arc-runner-set-${repo} \
          --namespace arc-runners \
          --create-namespace \
          --set githubConfigUrl="https://github.com/${githubUsername}/${repo}" \
          --set githubConfigSecret.github_token="$GITHUB_TOKEN" \
          --set runnerScaleSetName="${repo}" \
          --set minRunners=0 \
          --set maxRunners=5 \
          --set-json 'containerMode={"type":"dind"}' \
          ${optionalString cfg.useCustomImage "--set template.spec.containers[0].image=\"${runnerImageName}\""} \
          oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

        echo "Runner scale set for ${repo} deployed successfully"
      '';
    };
  };

  # ARC status monitoring script
  arc-status-script = pkgs.writeShellScriptBin "arc-status" ''
    #!/usr/bin/env bash
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'

    clear

    echo -e "''${BOLD}''${CYAN}╔════════════════════════════════════════════════════════════╗''${NC}"
    echo -e "''${BOLD}''${CYAN}║     GitHub Actions Runner Controller - Status Monitor      ║''${NC}"
    echo -e "''${BOLD}''${CYAN}╚════════════════════════════════════════════════════════════╝''${NC}"
    echo ""

    RUNNER_SETS=$(${pkgs.kubectl}/bin/kubectl get autoscalingrunnersets -n arc-runners -o json 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "''${RED}✗ Error: Cannot connect to k3s cluster''${NC}"
        exit 1
    fi

    echo "$RUNNER_SETS" | ${pkgs.jq}/bin/jq -r '.items[] | @json' | while read -r item; do
        NAME=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.metadata.name')
        REPO=$(echo "$NAME" | sed 's/^${hostname}-//')

        CURRENT=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.currentRunners // 0')
        PENDING=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.pendingRunners // 0')
        RUNNING=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.runningRunners // 0')
        FINISHED=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.finishedRunners // 0')
        MIN=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.spec.minRunners // "-"')
        MAX=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.spec.maxRunners // "∞"')

        if [ "$RUNNING" -gt 0 ]; then
            STATUS="''${GREEN}● ACTIVE''${NC}"
        elif [ "$PENDING" -gt 0 ]; then
            STATUS="''${YELLOW}◐ STARTING''${NC}"
        else
            STATUS="''${BLUE}○ IDLE''${NC}"
        fi

        echo -e "''${BOLD}Repository: ''${CYAN}$REPO''${NC} $STATUS"
        echo -e "  ''${BOLD}Name:''${NC} $NAME"
        echo -e "  ''${BOLD}Scale:''${NC} $MIN min → $MAX max"
        echo ""
        echo -e "  ''${BOLD}Runners:''${NC}"

        if [ "$CURRENT" -gt 0 ]; then
            echo -e "    ''${GREEN}■''${NC} Current:  $CURRENT"
        fi
        if [ "$RUNNING" -gt 0 ]; then
            echo -e "    ''${GREEN}▶''${NC} Running:  $RUNNING"
        fi
        if [ "$PENDING" -gt 0 ]; then
            echo -e "    ''${YELLOW}◷''${NC} Pending:  $PENDING"
        fi
        if [ "$FINISHED" -gt 0 ]; then
            echo -e "    ''${BLUE}✓''${NC} Finished: $FINISHED"
        fi
        if [ "$CURRENT" -eq 0 ] && [ "$PENDING" -eq 0 ]; then
            echo -e "    ''${BLUE}○''${NC} No active runners"
        fi

        echo ""
        echo "  ─────────────────────────────────────────────────────"
        echo ""
    done

    echo -e "''${BOLD}''${CYAN}Controller Status:''${NC}"
    CONTROLLER_POD=$(${pkgs.kubectl}/bin/kubectl get pods -n arc-systems -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -n "$CONTROLLER_POD" ]; then
        CONTROLLER_STATUS=$(${pkgs.kubectl}/bin/kubectl get pod "$CONTROLLER_POD" -n arc-systems -o jsonpath='{.status.phase}' 2>/dev/null)
        CONTROLLER_READY=$(${pkgs.kubectl}/bin/kubectl get pod "$CONTROLLER_POD" -n arc-systems -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$CONTROLLER_STATUS" = "Running" ] && [ "$CONTROLLER_READY" = "True" ]; then
            echo -e "  ''${GREEN}✓''${NC} ARC Controller: ''${GREEN}$CONTROLLER_STATUS''${NC}"
        else
            echo -e "  ''${YELLOW}◐''${NC} ARC Controller: ''${YELLOW}$CONTROLLER_STATUS''${NC}"
        fi

        LISTENERS=$(${pkgs.kubectl}/bin/kubectl get pods -n arc-runners -o json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.items[].metadata.name' 2>/dev/null | grep -c listener 2>/dev/null || echo 0)
        # Ensure LISTENERS is a valid integer
        if [[ "$LISTENERS" =~ ^[0-9]+$ ]] && [ "$LISTENERS" -gt 0 ]; then
            echo -e "  ''${GREEN}✓''${NC} Listener Pods: ''${GREEN}$LISTENERS active''${NC}"
        fi
    else
        echo -e "  ''${RED}✗''${NC} ARC Controller: Not found"
    fi

    echo ""
    echo -e "''${BOLD}k3s Cluster:''${NC}"
    NODE_STATUS=$(${pkgs.kubectl}/bin/kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$NODE_STATUS" = "True" ]; then
        echo -e "  ''${GREEN}✓''${NC} Cluster: ''${GREEN}Ready''${NC}"
    else
        echo -e "  ''${RED}✗''${NC} Cluster: ''${RED}Not Ready''${NC}"
    fi

    echo ""
    echo -e "''${BOLD}Commands:''${NC}"
    echo "  arc-status       - Show this status"
    echo "  arc-watch        - Watch status (auto-refresh)"
    echo "  arc-logs         - View controller logs"
    echo ""
  '';

  # ARC TUI monitoring script
  arc-tui-script = pkgs.writeShellScriptBin "arc-tui" ''
    #!/usr/bin/env bash
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    # Colors and styles
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'

    # Use alternate screen buffer to prevent flicker
    tput smcup
    tput civis
    trap 'tput rmcup; tput cnorm; exit' INT TERM EXIT

    while true; do
        tput cup 0 0

        # Header
        echo -e "''${CYAN}''${BOLD}▸ ACTIONS RUNNER CONTROLLER''${NC} ''${DIM}[yoga]''${NC}"
        echo ""

        # Get data
        RUNNER_DATA=$(${pkgs.kubectl}/bin/kubectl get autoscalingrunnersets -n arc-runners -o json 2>/dev/null)
        CONTROLLER_POD=$(${pkgs.kubectl}/bin/kubectl get pods -n arc-systems -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        LISTENER_PODS=$(${pkgs.kubectl}/bin/kubectl get pods -n arc-runners -o json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.items[] | select(.metadata.name | contains("listener")) | .metadata.name' 2>/dev/null)

        # System status
        if [ -n "$CONTROLLER_POD" ]; then
            CTRL_STATUS=$(${pkgs.kubectl}/bin/kubectl get pod "$CONTROLLER_POD" -n arc-systems -o jsonpath='{.status.phase}' 2>/dev/null)
            if [ "$CTRL_STATUS" = "Running" ]; then
                echo -e "''${GREEN}●''${NC} System operational"
            else
                echo -e "''${YELLOW}◐''${NC} System starting"
            fi
        else
            echo -e "''${RED}●''${NC} System offline"
        fi

        echo ""

        # Parse runner sets
        if [ -n "$RUNNER_DATA" ]; then
            echo "$RUNNER_DATA" | ${pkgs.jq}/bin/jq -c '.items[]' | while read -r item; do
                NAME=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.metadata.name')
                REPO=$(echo "$NAME" | sed 's/^${hostname}-//')

                CURRENT=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.currentRunners // 0')
                PENDING=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.pendingRunners // 0')
                RUNNING=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.runningRunners // 0')
                FINISHED=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.status.finishedRunners // 0')

                # Repository header with status
                if [ "$RUNNING" -gt 0 ]; then
                    echo -e "''${BOLD}''${REPO}''${NC} ''${GREEN}▶ ACTIVE''${NC}"
                elif [ "$PENDING" -gt 0 ]; then
                    echo -e "''${BOLD}''${REPO}''${NC} ''${YELLOW}◷ STARTING''${NC}"
                else
                    echo -e "''${BOLD}''${REPO}''${NC} ''${DIM}standby''${NC}"
                fi

                # Only show metrics if there's activity
                if [ "$CURRENT" -gt 0 ] || [ "$PENDING" -gt 0 ] || [ "$RUNNING" -gt 0 ]; then
                    if [ "$RUNNING" -gt 0 ]; then
                        echo -e "  ''${GREEN}▸''${NC} $RUNNING executing"
                    fi
                    if [ "$PENDING" -gt 0 ]; then
                        echo -e "  ''${YELLOW}▸''${NC} $PENDING provisioning"
                    fi
                    if [ "$FINISHED" -gt 0 ]; then
                        echo -e "  ''${DIM}▸''${NC} $FINISHED ''${DIM}completed''${NC}"
                    fi
                    echo ""
                fi
            done

            # Listener status (only if active)
            LISTENER_COUNT=$(echo "$LISTENER_PODS" | grep -c . 2>/dev/null || echo 0)
            if [[ "$LISTENER_COUNT" =~ ^[0-9]+$ ]] && [ "$LISTENER_COUNT" -gt 0 ]; then
                echo -e "''${DIM}━━━''${NC}"
                echo -e "''${DIM}$LISTENER_COUNT listeners active''${NC}"
                echo ""
            fi
        fi

        # Footer with timestamp
        echo ""
        echo -e "''${DIM}$(date '+%H:%M:%S') • Press Ctrl+C to exit''${NC}"

        sleep 0.1
    done
  '';
in
{
  config = mkIf cfg.enable {
    # Directly enable and configure k3s (bypass development feature to avoid recursion)
    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [ "--disable=traefik" ];
    };

    # Set KUBECONFIG environment variable
    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    # Open API port and trust k3s network interfaces
    networking.firewall = {
      allowedTCPPorts = [ 6443 ];
      trustedInterfaces = [ "cni0" "flannel.1" ];
    };

    # Prevent NetworkManager from managing k3s interfaces
    environment.etc."NetworkManager/conf.d/k3s-unmanaged.conf".text = ''
      [keyfile]
      unmanaged-devices=interface-name:cni*;interface-name:flannel*;interface-name:veth*
    '';

    # Install k8s tools and GitHub Actions packages
    environment.systemPackages = with pkgs; [
      kubectl
      kubernetes-helm
      k3s
      git
      jq
      arc-status-script
      arc-tui-script
    ];

    # Create GitHub token environment file from pass
    # This runs once at activation to populate the token file
    # To set the token: pass insert github/runner-pat
    system.activationScripts.createGithubRunnerToken = {
      text = ''
              if [ ! -f /persist/etc/github-runner-token ]; then
                echo "Creating GitHub runner token file..."
                mkdir -p /persist/etc

                # Try to get PAT from pass (run as configured user)
                if ${pkgs.sudo}/bin/sudo -u ${autoRunnerUser} ${pkgs.pass}/bin/pass show github/runner-pat &>/dev/null; then
                  GITHUB_TOKEN=$(${pkgs.sudo}/bin/sudo -u ${autoRunnerUser} ${pkgs.pass}/bin/pass show github/runner-pat)
                  cat > /persist/etc/github-runner-token << EOF
        GITHUB_TOKEN=$GITHUB_TOKEN
        GITHUB_USERNAME=${githubUsername}
        EOF
                  chmod 644 /persist/etc/github-runner-token
                  chown root:root /persist/etc/github-runner-token
                  echo "GitHub runner token file created from pass"
                else
                  echo "WARNING: GitHub PAT not found in pass at github/runner-pat"
                  echo "Please run: pass insert github/runner-pat"
                  echo "Then run: sudo nixos-rebuild switch"
                fi
              fi
      '';
      deps = [
        "users"
        "groups"
      ];
    };

    # Setup ARC controller and k3s kubeconfig permissions
    systemd.services = lib.listToAttrs (map mkRunnerSetService repositories) // {
      # Make kubeconfig readable by users
      k3s-kubeconfig-permissions = {
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

      arc-setup = {
        description = "Setup GitHub Actions Runner Controller";
        after = [ "k3s.service" ];
        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          ConditionPathExists = "!/var/lib/arc-setup-done";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          # Wait for k3s to be ready
          until ${pkgs.k3s}/bin/kubectl get nodes; do
            echo "Waiting for k3s..."
            sleep 5
          done

          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

          # Install cert-manager (required for ARC)
          ${pkgs.kubectl}/bin/kubectl apply -f \
            https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

          # Wait for cert-manager
          echo "Waiting for cert-manager to be ready..."
          sleep 30

          # Add ARC helm repo
          ${pkgs.kubernetes-helm}/bin/helm repo add actions-runner-controller \
            https://actions-runner-controller.github.io/actions-runner-controller

          ${pkgs.kubernetes-helm}/bin/helm repo update

          # Install ARC controller
          ${pkgs.kubernetes-helm}/bin/helm upgrade --install arc \
            --namespace arc-systems \
            --create-namespace \
            oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

          # Patch ClusterRole to add missing RBAC permissions for secrets and pods
          # The controller needs these to create JIT config secrets for runner pods
          # See: https://github.com/actions/actions-runner-controller/discussions/3160
          ${pkgs.kubectl}/bin/kubectl patch clusterrole arc-gha-rs-controller --type=json -p='[
            {"op": "add", "path": "/rules/-", "value": {
              "apiGroups": [""],
              "resources": ["secrets"],
              "verbs": ["create", "delete", "get", "list", "patch", "update", "watch"]
            }},
            {"op": "add", "path": "/rules/-", "value": {
              "apiGroups": [""],
              "resources": ["pods"],
              "verbs": ["create", "delete", "get", "patch", "update"]
            }},
            {"op": "add", "path": "/rules/-", "value": {
              "apiGroups": ["rbac.authorization.k8s.io"],
              "resources": ["roles", "rolebindings"],
              "verbs": ["create", "delete", "get", "patch", "update"]
            }}
          ]'

          echo "RBAC permissions patched for ARC controller"

          ${optionalString cfg.enableGpu (
            if autoGpuVendor == "amd" then ''
          # Install AMD GPU device plugin
          echo "Installing AMD GPU device plugin..."
          ${pkgs.kubectl}/bin/kubectl apply -f https://raw.githubusercontent.com/ROCm/k8s-device-plugin/master/k8s-ds-amdgpu-dp.yaml

          # Wait for device plugin to be ready
          echo "Waiting for GPU device plugin..."
          sleep 10
          '' else ''
          # Install NVIDIA GPU device plugin
          echo "Installing NVIDIA GPU device plugin..."
          ${pkgs.kubectl}/bin/kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/deployments/static/nvidia-device-plugin.yml

          # Wait for device plugin to be ready
          echo "Waiting for GPU device plugin..."
          sleep 10
          ''
          )}

          touch /var/lib/arc-setup-done
          echo "ARC controller installed successfully"
        '';
      };
    };
  };
}
