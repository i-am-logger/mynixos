# Assert that no two accounts share a uid, and no two groups share a gid.
#
# A uid or gid is the kernel's unit of authorisation. Names are a userspace
# convenience layered on top: two names on one number are ONE principal, and
# every permission granted to either is granted to both. `getent` prints both
# entries happily, resolution returns whichever it finds first, and `ls -l`
# then shows a file belonging to a group that never asked for it.
#
# NIXOS DOES NOT REJECT THIS, and it is not only a hand-pinning mistake.
#
# This fleet hit it twice. First with a hand-picked `uid = 989` that silently
# merged a container's forge account with `usbmux`, which had been allocated
# that number dynamically. The rule adopted then -- let the OS allocate, never
# pin -- was correct and turned out to be insufficient: the second collision
# was between `radicle-forge` and `fwupd-refresh`, BOTH allocated by NixOS,
# with the duplicate sitting in /var/lib/nixos/gid-map itself. The visible
# damage was /var/lib/fwupd reporting its group as the forge account.
#
# WHY THIS IS A UNIT AND NOT AN ASSERTION. A dynamically allocated id does not
# exist while modules evaluate -- it is assigned by update-users-groups.pl at
# activation -- so there is nothing for the module system to compare. The check
# has to run on the machine, after the accounts exist.
#
# WHY IT FAILS RATHER THAN WARNS. An activation-time warning is precisely what
# let both collisions ship: the text scrolls past in a rebuild that succeeds,
# and nothing afterwards is different. A failed unit is visible in
# `systemctl --failed` and stays visible.
#
# Modelled on platforms/oci.nix's `firewall-enforced`, which exists for the
# same reason: systemd SKIPS a unit whose condition is unmet, and that silence
# read as success.
{ pkgs, ... }:

{
  systemd.services.unique-ids-enforced = {
    description = "Assert no uid or gid is shared by two accounts";
    # After the accounts are created; that unit is what allocates the ids this
    # checks, so running before it would test the previous generation.
    after = [ "systemd-sysusers.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Named on the unit's PATH rather than interpolated per call. The first
    # version reached for `${"$"}{pkgs.glibc.bin}/bin/getent`, which does not
    # exist -- getent is its own package. Every invocation failed with "No such
    # file or directory", the failure was swallowed by the pipeline it fed, the
    # duplicate list came back empty, and the unit reported SUCCESS on a machine
    # with a live collision. A guard that passes because it could not run is
    # the exact failure this guard exists to catch.
    path = [ pkgs.getent pkgs.gawk pkgs.coreutils ];
    script = ''
      # pipefail is load-bearing here, not hygiene: without it a broken tool at
      # the head of a pipeline is invisible, which is how the above happened.
      set -euo pipefail

      # `getent` rather than reading /etc/passwd directly: it goes through NSS,
      # so this sees accounts as every other process does, including any that
      # do not come from the local files.
      #
      # Proving the tool works before trusting its silence. An empty duplicate
      # list is the PASSING answer, so it must not also be the answer produced
      # by a lookup that failed.
      if [ "$(getent passwd | wc -l)" -lt 2 ] || [ "$(getent group | wc -l)" -lt 2 ]; then
        echo "getent returned almost nothing -- NSS is not answering, so this" >&2
        echo "check cannot tell a clean system from a broken lookup." >&2
        exit 1
      fi

      duplicates() {
        # $1 = passwd|group. Field 3 is the id in both databases.
        getent "$1" | awk -F: '{ print $3 }' | sort -n | uniq -d
      }

      report() {
        local db="$1" kind="$2" id
        local found=""
        while read -r id; do
          [ -n "$id" ] || continue
          found=yes
          echo "  $kind $id is shared by: $(getent "$db" \
            | awk -F: -v I="$id" '$3 == I { printf "%s ", $1 }')" >&2
        done < <(duplicates "$db")
        [ -z "$found" ] || echo collision
      }

      dup_uid=$(report passwd uid)
      dup_gid=$(report group gid)

      if [ -n "$dup_uid" ] || [ -n "$dup_gid" ]; then
        echo "" >&2
        echo "Two or more accounts share an id. They are ONE principal to the" >&2
        echo "kernel: each can read and write whatever the other's permissions" >&2
        echo "allow, and file ownership will display under whichever name NSS" >&2
        echo "happens to return first." >&2
        echo "" >&2
        echo "Do NOT fix this by pinning an id -- that is what caused the first" >&2
        echo "collision on this fleet. Both sides of the second one were" >&2
        echo "allocated by NixOS, and the duplicate is recorded in" >&2
        echo "/var/lib/nixos/{uid,gid}-map. Free the id there, let the account" >&2
        echo "be reallocated, and chgrp what carries the old one." >&2
        echo "" >&2
        echo "Never chown recursively over a container state volume: those" >&2
        echo "files belong to the container's users mapped into a subuid range," >&2
        echo "and rewriting them makes them root INSIDE the container." >&2
        exit 1
      fi
    '';
  };
}
