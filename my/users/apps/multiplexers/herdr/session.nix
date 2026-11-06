# Who a shell in a herdr pane is, for tools that record the session behind a
# change: releasable reads RELEASABLE_SESSION and records it beside the
# repository, never in it.
#
# `shellInit` is what bash and zsh run when they start: in a herdr pane it
# exports RELEASABLE_SESSION as "<workspace id> <label>", or the id alone where
# herdr gives no label; anywhere else it exports nothing. It asks the herdr that
# started the pane ($HERDR_BIN_PATH), so client and server are one version. The
# value is read when the shell starts, about a millisecond: a workspace renamed
# later reaches the shells started after it, and a program already running keeps
# the value it started with.
{ lib, pkgs }:

rec {
  script = pkgs.writeShellScript "herdr-releasable-session" ''
    label=$("$HERDR_BIN_PATH" workspace get "$HERDR_WORKSPACE_ID" 2>/dev/null \
      | ${lib.getExe pkgs.jq} -r '.result.workspace.label // empty') || label=
    if [ -n "$label" ]; then
      printf '%s %s\n' "$HERDR_WORKSPACE_ID" "$label"
    else
      printf '%s\n' "$HERDR_WORKSPACE_ID"
    fi
  '';

  shellInit = ''
    if [ -n "''${HERDR_WORKSPACE_ID-}" ] && [ -n "''${HERDR_BIN_PATH-}" ]; then
      RELEASABLE_SESSION=$(${script}) && export RELEASABLE_SESSION
    fi
  '';
}
