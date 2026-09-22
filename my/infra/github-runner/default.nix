{ config, lib, pkgs, ... }:

# GitHub Actions Runner Controller (ARC) as a WORKLOAD.
#
# This module owns the runner concern and nothing else: the ARC controller, one
# runner scale set per repository, the GitHub PAT those need, and two status
# helpers. It does not own a cluster -- `my.infra.rke2` does, and the assertions
# below make the runner CONSUME that rather than stand up its own
# (docs/k8s-fleet-decision.md, "Disposition of the existing modules").
#
# What used to live here, and why none of it came back:
#
#   - a second `services.k3s` block. Two modules configuring one machine's
#     control plane is two owners for it; `my.infra.k3s` was deleted for the same
#     reason and this was the last of that duplication.
#   - a third writer of NetworkManager's `unmanaged-devices` key. It sorted AFTER
#     my/system/core's `99-unmanaged-cni.conf` ('k' = 0x6b > '9' = 0x39) and so
#     won the key with a shorter list, dropping the `podman*`/`docker*`/`br-*`
#     exclusions that keep NetworkManager off the running Radicle forge. Core is
#     the single owner (C64, C74); this is not relocated, it is gone.
#   - `environment.variables.KUBECONFIG` pointing every process on the host at
#     the cluster-admin credential (C45), and the `chmod 644` oneshot that made
#     that file readable to all of them (C43). The mode is now
#     `my.infra.rke2.kubeconfigMode`, which refuses a world bit at eval time; the
#     units and scripts here name the file per command instead.
#   - `/var/lib/rancher`, `/var/lib/kubelet` and `/var/lib/cni` as an
#     unconditional flat persistence list for a cluster this module does not own
#     -- also incomplete and ungated, so C62/C80 require it to be replaced by the
#     cluster domain's declaration rather than moved.
#   - `kubectl apply -f <github release URL>` and `helm repo add` at activation
#     (C50): cert-manager and the GPU device plugins. Those are cluster-wide
#     add-ons, fetched unpinned from third parties on every start, and a workload
#     is not where a cluster grows capabilities. See `enableGpu` below for the
#     half of GPU support that IS a runner concern.
#   - the `ConditionPathExists = "!/var/lib/arc-setup-done"` marker, which made
#     "has this already run?" a property of a file on a tmpfs rather than of the
#     cluster. Bootstrap is idempotent instead: `helm upgrade --install` is by
#     construction, and the one RBAC patch that is not now tests for its own
#     effect first.

with lib;

let
  cfg = config.my.infra.github-runner;
  rke2 = config.my.infra.rke2;
  persistPath = config.my.storage.impermanence.persistPath or "/persist";

  # The admin kubeconfig, which only an RKE2 SERVER writes -- an agent holds the
  # kubelet's credentials and nothing else. Root-owned at
  # `my.infra.rke2.kubeconfigMode` (0600), so naming the path here grants nothing
  # by itself: the units below run as root, and the helper scripts honour a
  # scoped KUBECONFIG the caller already has.
  kubeconfig = "/etc/rancher/rke2/rke2.yaml";

  tokenFile = "${persistPath}/etc/github-runner-token";

  kubectl = "${pkgs.kubectl}/bin/kubectl";
  helm = "${pkgs.kubernetes-helm}/bin/helm";
  jq = "${pkgs.jq}/bin/jq";

  hostname = config.networking.hostName;

  # Users who have said who they are on GitHub.
  githubUsers = filterAttrs (_: userCfg: userCfg.github.username != null) config.my.users;
  githubUserNames = attrNames githubUsers;

  # The account whose `pass` store holds the PAT and whose GHCR namespace holds
  # the runner image. One host, one token.
  #
  # Total on purpose: `head` on an empty list throws, and a throw in a let
  # binding pre-empts the assertion that exists to explain the problem.
  runnerUser = if githubUserNames == [ ] then "" else head githubUserNames;
  runnerAccount = if runnerUser == "" then "" else githubUsers.${runnerUser}.github.username;

  runnerImageName = "ghcr.io/${runnerAccount}/github-runner:latest";

  # { repo, owner } per repository. A repository is named by its OWNER, and the
  # owner is the user who declared it: two users on one host have two accounts,
  # and attributing everyone's repositories to the first user's username is how a
  # runner set gets registered against a URL that does not exist. The flat
  # `cfg.repositories` names no owner, so it takes the PAT account's.
  repositories =
    flatten
      (mapAttrsToList
        (_: userCfg: map (repo: { inherit repo; owner = userCfg.github.username; })
          userCfg.github.repositories)
        githubUsers)
    ++ map (repo: { inherit repo; owner = runnerAccount; }) cfg.repositories;

  # The resource name a GPU is REQUESTED by. Advertising it is a device plugin's
  # job and therefore the cluster's; asking for one is the runner's. If nothing
  # advertises the resource the runner pod stays Pending, which is visible in
  # `arc-status` -- unlike the old behaviour, where any vendor that was not "amd"
  # silently got NVIDIA's plugin applied to it.
  gpuVendor = config.my.hardware.gpu;
  gpuResource =
    if gpuVendor == "amd" then "amd.com/gpu"
    else if gpuVendor == "nvidia" then "nvidia.com/gpu"
    else null;

  # Per command, never fleet-wide (C45). A caller with a scoped credential keeps
  # it; the fallback is the admin file, which is root-only, so this grants an
  # unprivileged shell nothing it did not already have.
  kubeconfigPreamble = ''
    export KUBECONFIG="''${KUBECONFIG:-${kubeconfig}}"
  '';

  # Generate runner set services for each repository
  mkRunnerSetService = { repo, owner }: {
    name = "arc-runner-set-${repo}";
    value = {
      description = "Deploy GitHub Actions Runner Scale Set for ${owner}/${repo}";
      after = [ "arc-setup.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = tokenFile;
      };

      script = ''
        export KUBECONFIG=${kubeconfig}

        # Wait for ARC controller
        until ${kubectl} get namespace arc-systems; do
          echo "Waiting for ARC controller..."
          sleep 5
        done

        until ${kubectl} wait --namespace arc-systems \
          --for=condition=Available --timeout=60s deployment --all; do
          echo "Waiting for the ARC controller to become Available..."
          sleep 5
        done

        if [ -z "$GITHUB_TOKEN" ]; then
          echo "Error: GITHUB_TOKEN not found in environment file"
          exit 1
        fi

        # Install runner scale set for ${owner}/${repo} - repo-level registration
        # Using dind mode (requires the SidecarContainers feature gate)
        ${helm} upgrade --install arc-runner-set-${repo} \
          --namespace arc-runners \
          --create-namespace \
          --set githubConfigUrl="https://github.com/${owner}/${repo}" \
          --set githubConfigSecret.github_token="$GITHUB_TOKEN" \
          --set runnerScaleSetName="${repo}" \
          --set minRunners=0 \
          --set maxRunners=5 \
          --set-json 'containerMode={"type":"dind"}' \
          ${optionalString cfg.useCustomImage "--set template.spec.containers[0].image=\"${runnerImageName}\""} \
          ${optionalString cfg.enableGpu "--set-json 'template.spec.containers[0].resources={\"limits\":{\"${toString gpuResource}\":1}}'"} \
          oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

        echo "Runner scale set for ${owner}/${repo} deployed successfully"
      '';
    };
  };

  # ARC status monitoring script
  arc-status-script = pkgs.writeShellScriptBin "arc-status" ''
    #!/usr/bin/env bash
    ${kubeconfigPreamble}
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

    RUNNER_SETS=$(${kubectl} get autoscalingrunnersets -n arc-runners -o json 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "''${RED}✗ Error: Cannot reach the cluster''${NC}"
        exit 1
    fi

    echo "$RUNNER_SETS" | ${jq} -r '.items[] | @json' | while read -r item; do
        NAME=$(echo "$item" | ${jq} -r '.metadata.name')
        REPO=$(echo "$NAME" | sed 's/^arc-runner-set-//')

        CURRENT=$(echo "$item" | ${jq} -r '.status.currentRunners // 0')
        PENDING=$(echo "$item" | ${jq} -r '.status.pendingRunners // 0')
        RUNNING=$(echo "$item" | ${jq} -r '.status.runningRunners // 0')
        FINISHED=$(echo "$item" | ${jq} -r '.status.finishedRunners // 0')
        MIN=$(echo "$item" | ${jq} -r '.spec.minRunners // "-"')
        MAX=$(echo "$item" | ${jq} -r '.spec.maxRunners // "∞"')

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
    CONTROLLER_POD=$(${kubectl} get pods -n arc-systems -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -n "$CONTROLLER_POD" ]; then
        CONTROLLER_STATUS=$(${kubectl} get pod "$CONTROLLER_POD" -n arc-systems -o jsonpath='{.status.phase}' 2>/dev/null)
        CONTROLLER_READY=$(${kubectl} get pod "$CONTROLLER_POD" -n arc-systems -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$CONTROLLER_STATUS" = "Running" ] && [ "$CONTROLLER_READY" = "True" ]; then
            echo -e "  ''${GREEN}✓''${NC} ARC Controller: ''${GREEN}$CONTROLLER_STATUS''${NC}"
        else
            echo -e "  ''${YELLOW}◐''${NC} ARC Controller: ''${YELLOW}$CONTROLLER_STATUS''${NC}"
        fi

        LISTENERS=$(${kubectl} get pods -n arc-runners -o json 2>/dev/null | ${jq} -r '.items[].metadata.name' 2>/dev/null | grep -c listener 2>/dev/null || echo 0)
        # Ensure LISTENERS is a valid integer
        if [[ "$LISTENERS" =~ ^[0-9]+$ ]] && [ "$LISTENERS" -gt 0 ]; then
            echo -e "  ''${GREEN}✓''${NC} Listener Pods: ''${GREEN}$LISTENERS active''${NC}"
        fi
    else
        echo -e "  ''${RED}✗''${NC} ARC Controller: Not found"
    fi

    echo ""
    echo -e "''${BOLD}Cluster:''${NC}"
    NODE_STATUS=$(${kubectl} get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$NODE_STATUS" = "True" ]; then
        echo -e "  ''${GREEN}✓''${NC} Cluster: ''${GREEN}Ready''${NC}"
    else
        echo -e "  ''${RED}✗''${NC} Cluster: ''${RED}Not Ready''${NC}"
    fi

    echo ""
    echo -e "''${BOLD}Commands:''${NC}"
    echo "  arc-status       - Show this status"
    echo "  arc-tui          - Watch status (auto-refresh)"
    echo ""
  '';

  # ARC TUI monitoring script
  arc-tui-script = pkgs.writeShellScriptBin "arc-tui" ''
    #!/usr/bin/env bash
    ${kubeconfigPreamble}
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
        echo -e "''${CYAN}''${BOLD}▸ ACTIONS RUNNER CONTROLLER''${NC} ''${DIM}[${hostname}]''${NC}"
        echo ""

        # Get data
        RUNNER_DATA=$(${kubectl} get autoscalingrunnersets -n arc-runners -o json 2>/dev/null)
        CONTROLLER_POD=$(${kubectl} get pods -n arc-systems -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        LISTENER_PODS=$(${kubectl} get pods -n arc-runners -o json 2>/dev/null | ${jq} -r '.items[] | select(.metadata.name | contains("listener")) | .metadata.name' 2>/dev/null)

        # System status
        if [ -n "$CONTROLLER_POD" ]; then
            CTRL_STATUS=$(${kubectl} get pod "$CONTROLLER_POD" -n arc-systems -o jsonpath='{.status.phase}' 2>/dev/null)
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
            echo "$RUNNER_DATA" | ${jq} -c '.items[]' | while read -r item; do
                NAME=$(echo "$item" | ${jq} -r '.metadata.name')
                REPO=$(echo "$NAME" | sed 's/^arc-runner-set-//')

                CURRENT=$(echo "$item" | ${jq} -r '.status.currentRunners // 0')
                PENDING=$(echo "$item" | ${jq} -r '.status.pendingRunners // 0')
                RUNNING=$(echo "$item" | ${jq} -r '.status.runningRunners // 0')
                FINISHED=$(echo "$item" | ${jq} -r '.status.finishedRunners // 0')

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
    # -----------------------------------------------------------------------
    # The runner CONSUMES a cluster; it does not stand one up.
    #
    # Enabling RKE2 implicitly from here would put a Kubernetes control plane on
    # a machine as a side effect of wanting CI runners, which is exactly the
    # coupling that splitting these two modules exists to remove. So the host
    # says both, and this says so when it has not.
    # -----------------------------------------------------------------------
    assertions = [
      {
        assertion = rke2.enable;
        message = ''
          my.infra.github-runner.enable = true with my.infra.rke2.enable = false.

          ARC is a Kubernetes workload: this module installs the controller and
          one runner scale set per repository into a cluster it does not own.
          Enable the cluster explicitly on this host:

            my.infra.rke2.enable = true;

          It is deliberately not turned on implicitly (docs/k8s-fleet-decision.md,
          "Disposition of the existing modules").
        '';
      }
      {
        assertion = rke2.role == "server";
        message = ''
          my.infra.github-runner.enable = true on an RKE2 agent.

          Every unit here drives the cluster through the local admin kubeconfig
          at ${kubeconfig}, and only a server writes that file -- an agent holds
          the kubelet's credentials and nothing else. Put the runner stack on the
          control-plane node.
        '';
      }
      {
        assertion = githubUserNames != [ ];
        message = ''
          my.infra.github-runner.enable = true with no GitHub identity.

          The module registers runner sets against github.com/<owner>/<repo> and
          reads the PAT from a user's `pass` store, so at least one entry in
          my.users must set `github.username`.
        '';
      }
      {
        assertion = cfg.enableGpu -> gpuResource != null;
        message = ''
          my.infra.github-runner.enableGpu = true with my.hardware.gpu =
          ${if gpuVendor == null then "null" else gpuVendor}.

          A runner asks for a GPU by resource name, and there are two this module
          knows: amd.com/gpu and nvidia.com/gpu. Set my.hardware.gpu to the
          vendor this host actually has, or leave enableGpu off -- guessing a
          vendor is how the previous version applied NVIDIA's device plugin to an
          Intel machine.

          Note that ADVERTISING the resource is a device plugin's job, and a
          device plugin is a cluster-wide add-on: the cluster must deploy one, or
          the runner pods stay Pending.
        '';
      }
    ];

    # Only what this module itself provides. kubectl, helm and k9s arrive as
    # per-user apps under my/users/apps, on both platforms, so that "this machine
    # talks to the cluster" and "this machine is in it" stay separable (C5, C6);
    # the units and scripts here reference their tools by store path regardless.
    environment.systemPackages = [
      arc-status-script
      arc-tui-script
    ];

    # Create GitHub token environment file from pass
    # This runs once at activation to populate the token file
    # To set the token: pass insert github/runner-pat
    system.activationScripts.createGithubRunnerToken = {
      text = ''
        if [ ! -f ${tokenFile} ]; then
          echo "Creating GitHub runner token file..."
          mkdir -p ${persistPath}/etc

          # Try to get PAT from pass (run as the account that holds it)
          if ${pkgs.sudo}/bin/sudo -u ${runnerUser} ${pkgs.pass}/bin/pass show github/runner-pat &>/dev/null; then
            GITHUB_TOKEN=$(${pkgs.sudo}/bin/sudo -u ${runnerUser} ${pkgs.pass}/bin/pass show github/runner-pat)

            # umask, not a chmod afterwards: the PAT must never exist at the
            # default mode, not even for the width of one write.
            (
              umask 077
              {
                echo "GITHUB_TOKEN=$GITHUB_TOKEN"
                echo "GITHUB_USERNAME=${runnerAccount}"
              } > ${tokenFile}
            )
            chown root:root ${tokenFile}
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

    systemd.services = listToAttrs (map mkRunnerSetService repositories) // {
      arc-setup = {
        description = "Setup GitHub Actions Runner Controller";
        after = [ "rke2-server.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          export KUBECONFIG=${kubeconfig}

          # Wait for the cluster's API
          until ${kubectl} get nodes; do
            echo "Waiting for the cluster API..."
            sleep 5
          done

          # The ARC controller, from the chart's own OCI reference. cert-manager
          # is NOT installed here: it was fetched unpinned from a GitHub release
          # URL on every start (C50), and a cluster-wide add-on is the cluster's
          # to declare, not a workload's.
          ${helm} upgrade --install arc \
            --namespace arc-systems \
            --create-namespace \
            oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

          # RBAC the chart does not grant itself: the controller creates the JIT
          # config secrets and the pods that consume them.
          # See: https://github.com/actions/actions-runner-controller/discussions/3160
          #
          # `add` to `/rules/-` appends, so re-running would stack duplicate
          # rules every boot. The guard is the cluster's own state rather than a
          # marker file on a tmpfs -- and it re-fires by itself after a `helm
          # upgrade` reverts the ClusterRole to the chart's version.
          if ! ${kubectl} get clusterrole arc-gha-rs-controller -o json \
            | ${jq} -e 'any(.rules[]; (.resources // []) | index("secrets"))' >/dev/null; then
            ${kubectl} patch clusterrole arc-gha-rs-controller --type=json -p='[
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
          fi

          echo "ARC controller installed successfully"
        '';
      };
    };
  };
}
