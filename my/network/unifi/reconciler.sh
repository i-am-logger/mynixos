#!/usr/bin/env bash
# UniFi controller declarative reconciler (REST API backend).
#
# Subcommands:
#   inventory                  Print current state as YAML.
#   plan                       Diff UNIFI_DESIRED_STATE against live controller.
#   apply --confirm            Apply UNIFI_DESIRED_STATE (with confirmation).
#
# Environment (set by the NixOS module from my.network.unifi.*):
#   UNIFI_URL=https://10.45.128.1
#   UNIFI_SITE=default
#   UNIFI_API_KEY_FILE=/run/secrets/unifi-api-key
#   UNIFI_DESIRED_STATE=/run/secrets/unifi-desired
#
# All controller writes go through the validated REST API; no mongo direct.

set -euo pipefail

UNIFI_URL="${UNIFI_URL:-https://10.45.128.1}"
UNIFI_SITE="${UNIFI_SITE:-default}"
UNIFI_API_KEY_FILE="${UNIFI_API_KEY_FILE:-}"
UNIFI_DESIRED_STATE="${UNIFI_DESIRED_STATE:-}"

err() { echo "ERROR: $*" >&2; }

require_api_key() {
  if [ -z "$UNIFI_API_KEY_FILE" ]; then
    err "UNIFI_API_KEY_FILE not set"
    exit 2
  fi
  if [ ! -r "$UNIFI_API_KEY_FILE" ]; then
    err "UNIFI_API_KEY_FILE not readable: $UNIFI_API_KEY_FILE"
    exit 2
  fi
}

require_desired_state() {
  if [ -z "$UNIFI_DESIRED_STATE" ]; then
    err "UNIFI_DESIRED_STATE not set (point at a YAML file, typically a sops secret)"
    exit 2
  fi
  if [ ! -r "$UNIFI_DESIRED_STATE" ]; then
    err "UNIFI_DESIRED_STATE not readable: $UNIFI_DESIRED_STATE"
    exit 2
  fi
}

api_key() { tr -d '\n\r ' <"$UNIFI_API_KEY_FILE"; }

# Curl wrapper: returns body, exits non-zero on HTTP >= 400 with diagnostics.
api() {
  local method="$1" path="$2"
  local body="${3:-}"
  local tmp_body tmp_status
  tmp_body=$(mktemp)
  tmp_status=$(mktemp)
  trap 'rm -f "$tmp_body" "$tmp_status"' RETURN

  local args=(
    -sk
    -X "$method"
    -H "X-API-KEY: $(api_key)"
    -H "Accept: application/json"
    -o "$tmp_body"
    -w "%{http_code}"
  )
  if [ -n "$body" ]; then
    args+=(-H "Content-Type: application/json" --data "$body")
  fi

  curl "${args[@]}" "$UNIFI_URL$path" >"$tmp_status" || {
    err "curl failed for $method $path"
    cat "$tmp_body" >&2 || true
    return 1
  }

  local status
  status=$(cat "$tmp_status")
  if [ "$status" -ge 400 ]; then
    err "HTTP $status for $method $path"
    cat "$tmp_body" >&2 || true
    return 1
  fi

  cat "$tmp_body"
}

# Convenience getters
fetch_networks() {
  api GET "/proxy/network/api/s/${UNIFI_SITE}/rest/networkconf" | jq '.data'
}

# Build YAML matching the desired-state schema from REST response.
inventory_to_yaml() {
  local raw="$1"
  local networks wans

  networks=$(echo "$raw" | jq '
    [.[] | select(.purpose == "corporate") | {
      (.name): {
        purpose: .purpose,
        vlan: .vlan,
        subnet: .ip_subnet,
        enabled: (.enabled // true),
        ipv6: {
          mode: .ipv6_interface_type,
          pdInterface: (.ipv6_pd_interface // null)
        }
      }
    }] | add // {}
  ')

  wans=$(echo "$raw" | jq '
    [.[] | select(.purpose == "wan") | {
      (.name): {
        type: .wan_type,
        failoverPriority: .wan_failover_priority,
        ipv6: {
          type: .wan_type_v6,
          delegationType: .ipv6_wan_delegation_type,
          pdSizeAuto: .wan_dhcpv6_pd_size_auto
        }
      }
    }] | add // {}
  ')

  jq -n --argjson n "$networks" --argjson w "$wans" '{networks: $n, wans: $w}' |
    yq -p json -o yaml
}

cmd_inventory() {
  require_api_key
  local raw
  raw=$(fetch_networks)
  inventory_to_yaml "$raw"
}

cmd_plan() {
  require_api_key
  require_desired_state

  local current_yaml desired_yaml tmp_current tmp_desired
  tmp_current=$(mktemp)
  tmp_desired=$(mktemp)
  trap 'rm -f "$tmp_current" "$tmp_desired"' EXIT

  current_yaml=$(cmd_inventory)
  desired_yaml=$(yq -p yaml -o yaml '.' "$UNIFI_DESIRED_STATE")

  echo "$current_yaml" >"$tmp_current"
  echo "$desired_yaml" >"$tmp_desired"

  echo "=== Plan: current → desired ==="
  if diff -u --label "current (live)" --label "desired ($UNIFI_DESIRED_STATE)" \
    "$tmp_current" "$tmp_desired"; then
    echo "(no differences — controller already matches desired state)"
    return 0
  fi
}

# For each desired entry, find the live doc, merge changes, PUT back.
cmd_apply() {
  if [ "${1:-}" != "--confirm" ]; then
    err "'apply' requires --confirm. Run 'unifi-reconciler plan' first."
    exit 2
  fi
  require_api_key
  require_desired_state

  echo "=== Plan ==="
  local plan_rc=0
  cmd_plan || plan_rc=$?
  if [ "$plan_rc" -eq 0 ]; then
    echo "Nothing to apply."
    return 0
  fi
  echo

  read -r -p "Type 'apply' to proceed: " resp
  if [ "$resp" != "apply" ]; then
    echo "Aborted."
    return 1
  fi

  local desired_json current_json
  desired_json=$(yq -p yaml -o json '.' "$UNIFI_DESIRED_STATE")
  current_json=$(fetch_networks)

  # Apply networks
  echo "$desired_json" |
    jq -r '(.networks // {}) | to_entries[] | @json' |
    while IFS= read -r entry; do
      local name desired_cfg current_doc current_id merged
      name=$(echo "$entry" | jq -r '.key')
      desired_cfg=$(echo "$entry" | jq '.value')

      current_doc=$(echo "$current_json" |
        jq --arg n "$name" '.[] | select(.purpose == "corporate" and .name == $n)')

      if [ -z "$current_doc" ] || [ "$current_doc" = "null" ]; then
        err "network '$name' not found on controller; create-via-API not yet implemented"
        continue
      fi

      current_id=$(echo "$current_doc" | jq -r '._id')

      merged=$(jq -n \
        --argjson current "$current_doc" \
        --argjson desired "$desired_cfg" '
            $current
            + (if $desired.purpose != null then { purpose: $desired.purpose } else {} end)
            + (if $desired.vlan != null then { vlan: $desired.vlan } else {} end)
            + (if $desired.subnet != null then { ip_subnet: $desired.subnet } else {} end)
            + (if $desired.enabled != null then { enabled: $desired.enabled } else {} end)
            + (if $desired.ipv6.mode != null then { ipv6_interface_type: $desired.ipv6.mode } else {} end)
            + (if $desired.ipv6.pdInterface != null then { ipv6_pd_interface: $desired.ipv6.pdInterface } else {} end)
          ')

      echo "  PUT network '$name' (_id=$current_id)"
      api PUT "/proxy/network/api/s/${UNIFI_SITE}/rest/networkconf/$current_id" "$merged" |
        jq -r '"    rc=" + (.meta.rc // "?")'
    done

  # Apply WANs
  echo "$desired_json" |
    jq -r '(.wans // {}) | to_entries[] | @json' |
    while IFS= read -r entry; do
      local name desired_cfg current_doc current_id merged
      name=$(echo "$entry" | jq -r '.key')
      desired_cfg=$(echo "$entry" | jq '.value')

      current_doc=$(echo "$current_json" |
        jq --arg n "$name" '.[] | select(.purpose == "wan" and .name == $n)')

      if [ -z "$current_doc" ] || [ "$current_doc" = "null" ]; then
        err "wan '$name' not found on controller"
        continue
      fi

      current_id=$(echo "$current_doc" | jq -r '._id')

      merged=$(jq -n \
        --argjson current "$current_doc" \
        --argjson desired "$desired_cfg" '
            $current
            + (if $desired.type != null then { wan_type: $desired.type } else {} end)
            + (if $desired.failoverPriority != null then { wan_failover_priority: $desired.failoverPriority } else {} end)
            + (if $desired.ipv6.type != null then { wan_type_v6: $desired.ipv6.type } else {} end)
            + (if $desired.ipv6.delegationType != null then { ipv6_wan_delegation_type: $desired.ipv6.delegationType } else {} end)
            + (if $desired.ipv6.pdSizeAuto != null then { wan_dhcpv6_pd_size_auto: $desired.ipv6.pdSizeAuto } else {} end)
          ')

      echo "  PUT wan '$name' (_id=$current_id)"
      api PUT "/proxy/network/api/s/${UNIFI_SITE}/rest/networkconf/$current_id" "$merged" |
        jq -r '"    rc=" + (.meta.rc // "?")'
    done

  echo
  echo "Done. Controller validates each PUT; rejected changes show up as HTTP 4xx above."
}

usage() {
  cat <<EOF
unifi-reconciler — declarative UniFi controller config (REST)

Subcommands:
  inventory                  Print current state as YAML.
  plan                       Diff UNIFI_DESIRED_STATE against live controller.
  apply --confirm            Apply UNIFI_DESIRED_STATE (interactive prompt).

Env:
  UNIFI_URL=$UNIFI_URL
  UNIFI_SITE=$UNIFI_SITE
  UNIFI_API_KEY_FILE=${UNIFI_API_KEY_FILE:-(unset)}
  UNIFI_DESIRED_STATE=${UNIFI_DESIRED_STATE:-(unset)}
EOF
}

case "${1:-}" in
inventory)
  shift
  cmd_inventory "$@"
  ;;
plan)
  shift
  cmd_plan "$@"
  ;;
apply)
  shift
  cmd_apply "$@"
  ;;
"" | -h | --help | help) usage ;;
*)
  usage
  exit 2
  ;;
esac
