# A signing service end to end: git signs a tag through the socket, and every
# other way to the key is closed to the accounts on the machine.
#
# tests/signing-service.nix proves the unit's shape. This proves what only a
# running system can: the machine really generates and keeps the key, LoadCredential
# really hands it to the handler, the confinement leaves a handler able to read a
# repository under a home directory it can't otherwise reach, and the paths a
# client would try really refuse it. Each refusal has a control showing the path
# exists, so a typo can't pass as a refusal.
#
# The handler is a fixture: what a signature should require belongs to the tool.
# Two checkouts under my.infra.signing.releasable show one key serving two
# repositories, each through an instance of its own: its own socket, and a
# handler that sees only that repository's history.
#
# Heavy (boots a VM, needs /dev/kvm) => `tests` output:
#   nix build .#tests.<sys>.vm-signing-service -L
{ self, inputs, system, nixpkgs, ... }:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  socket = "/run/signing/tool.sock";
  repo = "/home/alice/repo";

  # Signs a tag only if the repository holds the object it points at.
  handler = pkgs.writeShellApplication {
    name = "fixture-handler";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.git pkgs.openssh ];
    text = ''
      echo "handler-view home=[$(ls -A /home/alice)] uid=$(id -un)" >&2
      work=$(mktemp -d)
      IFS= read -r namespace
      cat > "$work/payload"
      object=$(awk '$1 == "object" { print $2; exit }' "$work/payload")
      if ! git -c safe.directory='*' -C ${repo}/.git cat-file -e "$object"; then
        echo "refused: no such object" >&2
        exit 1
      fi
      ssh-keygen -q -Y sign -n "$namespace" -f "$CREDENTIALS_DIRECTORY/signing-key" "$work/payload"
      cat "$work/payload.sig"
    '';
  };

  # What git runs as gpg.ssh.program: -Y sign -n <namespace> -f <key> <file>.
  mkClient = name: socket: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.netcat-openbsd pkgs.openssh ];
    text = ''
      # git runs this program to verify as well, and that needs no key.
      if [ "$2" != sign ]; then
        exec ssh-keygen "$@"
      fi
      namespace=$4
      file=''${*: -1}
      # -N ends the request at the end of input, then the reply is read until the
      # handler closes the connection, however long the handler takes to start.
      { echo "$namespace"; cat "$file"; } | nc -N -U ${socket} > "$file.sig"
      test -s "$file.sig"
    '';
  };
  client = mkClient "fixture-client" socket;

  # my.infra.signing.releasable runs `<package> signing handle --repo <checkout>/.git`.
  # This stands in for releasable, with the same object check as the handler
  # above against the repository it is given. It carries no git of its own:
  # the service's PATH has to.
  releasable = pkgs.writeShellApplication {
    name = "releasable";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.openssh ];
    text = ''
      [ "$1 $2 $3" = "signing handle --repo" ] || { echo "unexpected arguments: $*" >&2; exit 2; }
      gitdir=$4
      readable=$(for key in /var/lib/signing-*/key; do if [ -r "$key" ]; then echo "$key"; fi; done)
      echo "releasable-view repo=$gitdir home=[$(ls -A /home/alice)] uid=$(id -un) readable=[$readable]" >&2
      work=$(mktemp -d)
      IFS= read -r namespace
      cat > "$work/payload"
      object=$(awk '$1 == "object" { print $2; exit }' "$work/payload")
      if ! git -c safe.directory='*' -C "$gitdir" cat-file -e "$object"; then
        echo "refused: $gitdir has no such object" >&2
        exit 1
      fi
      ssh-keygen -q -Y sign -n "$namespace" -f "$CREDENTIALS_DIRECTORY/signing-key" "$work/payload"
      cat "$work/payload.sig"
    '';
  };
  alphaClient = mkClient "alpha-client" "/run/signing/alpha.sock";
  betaClient = mkClient "beta-client" "/run/signing/beta.sock";
in
pkgs.testers.runNixOSTest {
  name = "vm-signing-service";

  node.specialArgs = {
    inherit inputs self pkgs;
    inherit (inputs)
      disko
      impermanence
      vogix
      hypr-vogix
      lanzaboote
      sops-nix
      ;
  };

  nodes.machine = { ... }: {
    imports = [
      self.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    boot.loader.grub.enable = false;
    system.stateVersion = "24.11";

    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [{ home.stateVersion = "24.11"; }];
    };

    users.users = {
      alice = { isNormalUser = true; };
      bob = { isNormalUser = true; };
    };

    environment.systemPackages = [ client alphaClient betaClient pkgs.acl pkgs.git pkgs.openssh pkgs.socat ];

    my = {
      system.enable = true;
      system.hostname = "machine";
      theming.enable = false;
      infra.signing.services.tool = {
        inherit handler;
        clients = [ "alice" ];
        instances.tool.readOnlyPaths = [ "${repo}/.git" ];
      };
      infra.signing.releasable = {
        package = releasable;
        repositories = { alpha = "/home/alice/alpha"; beta = "/home/alice/beta"; };
        clients = [ "alice" ];
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("signing-tool.socket")
    machine.wait_for_unit("signing-tool-keygen.service")

    alice = lambda c: f"su - alice -c '{c}'"
    bob = lambda c: f"su - bob -c '{c}'"

    with subtest("git signs a tag through the socket, and it verifies"):
        machine.succeed(alice(" && ".join([
            # Readable by the handler, the mode an ordinary checkout has.
            "umask 022",
            "git init -q repo",
            "cd repo",
            "git config user.name alice",
            "git config user.email alice@example.test",
            "git config gpg.format ssh",
            "git config gpg.ssh.program fixture-client",
            "git config user.signingkey /var/lib/signing-tool/key.pub",
            "git commit -q --allow-empty -m first",
            "git tag -s -m one v1",
            "(printf \"alice@example.test \"; cat /var/lib/signing-tool/key.pub) > ~/signers",
            "git config gpg.ssh.allowedSignersFile ~/signers",
        ])))
        out = machine.succeed(alice("cd repo && git verify-tag v1 2>&1"))
        assert 'Good "git" signature' in out, out

    with subtest("the handler decides: it refuses an object the repository lacks"):
        machine.succeed(alice("printf \"object 0000000000000000000000000000000000000000\\n\" > ~/bogus"))
        machine.fail(alice("fixture-client -Y sign -n git -f /var/lib/signing-tool/key.pub ~/bogus"))
        machine.succeed("journalctl --no-pager | grep -F 'refused: no such object'")

    with subtest("the handler runs as its own account and sees only what is listed"):
        machine.succeed("touch /home/alice/private-file")
        machine.succeed(alice("cd repo && git tag -s -m two v2"))
        out = machine.succeed("journalctl --no-pager | grep -F handler-view | tail -n 1")
        assert "home=[repo]" in out and "uid=signing-tool" in out, out

    with subtest("each releasable checkout signs through its own socket, with the one pre-release key"):
        machine.wait_for_unit("signing-pre-release-keygen.service")
        for name in ["alpha", "beta"]:
            machine.wait_for_unit(f"signing-{name}.socket")
            machine.succeed(alice(" && ".join([
                "umask 022",
                f"git init -q {name}",
                f"cd {name}",
                "git config user.name alice",
                "git config user.email alice@example.test",
                "git config gpg.format ssh",
                f"git config gpg.ssh.program {name}-client",
                "git config user.signingkey /var/lib/signing-pre-release/key.pub",
                f"git commit -q --allow-empty -m {name}",
                "git tag -s -m one v1",
                "(printf \"alice@example.test \"; cat /var/lib/signing-pre-release/key.pub) > ~/pre-release-signers",
                "git config gpg.ssh.allowedSignersFile ~/pre-release-signers",
            ])))
            out = machine.succeed(alice(f"cd {name} && git verify-tag v1 2>&1"))
            assert 'Good "git" signature' in out, out
        machine.fail("test -e /var/lib/signing-alpha || test -e /var/lib/signing-beta")

    with subtest("a releasable checkout's handler sees only its own history, and no other service's key"):
        commit = machine.succeed(alice("git -C alpha rev-parse HEAD")).strip()
        machine.succeed(alice(f"printf \"object {commit}\\n\" > ~/alpha-object"))
        machine.fail(alice("beta-client -Y sign -n git -f /var/lib/signing-pre-release/key.pub ~/alpha-object"))
        machine.succeed("journalctl --no-pager | grep -F 'refused: /home/alice/beta/.git has no such object'")
        machine.succeed(alice("alpha-client -Y sign -n git -f /var/lib/signing-pre-release/key.pub ~/alpha-object"))
        for name in ["alpha", "beta"]:
            view = machine.succeed(
                f"journalctl --no-pager | grep -F 'releasable-view repo=/home/alice/{name}/.git' | tail -n 1"
            )
            assert f"home=[{name}]" in view and "uid=signing-pre-release" in view, view
            # signing-tool's key is on the machine and closed to it.
            assert "readable=[/var/lib/signing-pre-release/key]" in view, view

    with subtest("a client can connect and an account not listed can't"):
        acl = machine.succeed("getfacl -p ${socket}")
        assert "user:alice:rw-" in acl and "user:bob" not in acl, acl
        machine.fail(bob("printf x | socat - UNIX-CONNECT:${socket}"))

    with subtest("the key at rest is closed to a client, and its public half isn't"):
        machine.succeed("grep -q 'OPENSSH PRIVATE KEY' /var/lib/signing-tool/key")
        assert machine.succeed("stat -c '%a %U' /var/lib/signing-tool/key").strip() == "400 signing-tool"
        machine.fail(alice("cat /var/lib/signing-tool/key"))
        machine.fail(bob("cat /var/lib/signing-tool/key"))
        machine.succeed(bob("ssh-keygen -lf /var/lib/signing-tool/key.pub"))

    with subtest("the key in use is closed to a client"):
        # An open connection keeps one handler alive, holding its credential.
        machine.succeed(
            "systemd-run --uid=alice --unit=held-connection "
            "${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/sleep 300 | ${pkgs.socat}/bin/socat - UNIX-CONNECT:${socket}'"
        )
        machine.wait_until_succeeds("systemctl list-units --no-legend 'signing-tool@*' | grep -q running")
        unit = machine.succeed(
            "systemctl list-units --state=running --no-legend --plain 'signing-tool@*' | awk '{print $1}' | head -n 1"
        ).strip()
        pid = machine.succeed(f"systemctl show -p MainPID --value {unit}").strip()
        credential = f"/run/credentials/{unit}/signing-key"
        # The credential is mounted in the handler's own namespace; root can enter it.
        machine.succeed(f"nsenter -t {pid} -m grep -q 'OPENSSH PRIVATE KEY' {credential}")
        machine.fail(alice(f"nsenter -t {pid} -m cat {credential}"))
        machine.fail(alice(f"cat {credential}"))
        machine.fail(alice(f"ls /run/credentials/{unit}"))
        machine.succeed(f"test -e /proc/{pid}/environ")
        machine.fail(alice(f"cat /proc/{pid}/environ"))
        machine.fail(alice(f"ls /proc/{pid}/root/"))
        machine.fail(alice(f"ls /proc/{pid}/fd/"))
        machine.succeed("systemctl stop held-connection")

    with subtest("the key reached no other place"):
        # The key's first body line is the same in every unencrypted ed25519 key,
        # and the next holds the public key; lines 4 and 5 are its own secret.
        for line in [4, 5]:
            body = machine.succeed(f"sed -n {line}p /var/lib/signing-tool/key").strip()
            assert len(body) == 70, body
            machine.succeed(f"grep -qF -- '{body}' /var/lib/signing-tool/key")
            machine.fail(f"grep -rFl --exclude-dir=signing-tool -- '{body}' /etc /var/lib /tmp /var/tmp /home")

    with subtest("the machine keeps one key, across a restart and a reboot"):
        fingerprint = lambda: machine.succeed("ssh-keygen -lf /var/lib/signing-tool/key.pub").strip()
        first = fingerprint()
        machine.succeed("systemctl restart signing-tool-keygen.service")
        assert fingerprint() == first, "restarting the generator made a new key"
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("signing-tool-keygen.service")
        assert fingerprint() == first, "a reboot made a new key"
        machine.succeed(alice("cd repo && git tag -s -m three v3"))
        out = machine.succeed(alice("cd repo && git verify-tag v3 2>&1"))
        assert 'Good "git" signature' in out, out
  '';
}
