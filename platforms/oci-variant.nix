# mynixos composition layer: a ROLE, emitted as an OCI container image.
#
# A role is a machine. It runs systemd, it has its own nginx if it serves
# something, and the domain it exists for -- my.infra.radicle, today -- runs
# inside it UNCHANGED. That is the whole reason this file imports ./linux.nix
# wholesale rather than curating a smaller list: the moment the module set
# diverges, `LoadCredential`, `StateDirectory`, `systemd.paths` and per-unit
# confinement start needing container-shaped reimplementations, and every one
# of those reimplementations is a bug this repo already fixed once.
#
# What a role must NOT do is boot like a host. Two of nixosModules.default's
# flake inputs describe a host's boot:
#
#   * lanzaboote  -- signs an EFI stub for a bootloader a container has not got;
#   * impermanence -- describes what survives a tmpfs root being wiped, when the
#     image IS the root and nothing wipes it.
#
# Both are nevertheless LOADED by `nixosModules.oci` (see flake.nix), and that
# is not an oversight. ./linux.nix writes `boot.lanzaboote` and
# `environment.persistence` under `mkIf`, and the module system pushes a
# condition DOWN to the leaves -- so a `mkIf false` definition still requires
# the option to be declared. Leaving the two modules out does not produce the
# error one would want ("secure boot is not a thing here"); it produces "The
# option `boot.lanzaboote' does not exist" from a module that is switched off.
#
# Both are inert until enabled, so what actually forbids them in a role is the
# pair of assertions below, which say why in a sentence.
#
# The container shape itself comes from nixpkgs' own docker-container profile:
# `boot.isContainer = true` (no kernel, no initrd, no bootloader, no
# systemd-udev-trigger, no sys-kernel-config.mount), `/init` -> `$toplevel/init`
# on switch, and the `register-nix-paths` service that loads the nix DB from
# /nix-path-registration -- which is what makes nix usable inside a builder.
#
# ../my/system/oci-image turns the resulting system into `system.build.image`.
#
#
# A role does not boot with a host's PRIVILEGES either, and that is the other
# half of this file. Rootless podman hands PID 1 a capability bounding set of
# CHOWN, DAC_OVERRIDE, FOWNER, FSETID, KILL, SETGID, SETUID, SETPCAP,
# NET_BIND_SERVICE, SYS_CHROOT and SETFCAP -- and no CAP_SYS_ADMIN. Two
# consequences, worth keeping apart because they look nothing alike in a
# journal:
#
#   * nothing may call mount(2), so a unit whose MECHANISM is a mount dies;
#   * a unit that both drops to a `User=` and installs a seccomp filter dies at
#     step USER with "Failed to keep CAP_SYS_ADMIN", because systemd wants to
#     retain that capability across the setresuid() so it can install the filter
#     on the far side of it.
#
# What is NOT a problem is per-unit sandboxing on its own: `ProtectSystem=`,
# `PrivateTmp=`, `ProtectHome=` and the rest report ENOANO, and systemd carries
# on without them. That is why the radicle units are untouched here, and why the
# sandboxing that survives below stays declared where it cannot take hold.
#
# Granting the container CAP_SYS_ADMIN would answer every case at once, and is
# deliberately not the answer: a builder role runs repository-supplied shell.
#
# Four host defaults are what that costs, and each is settled below. All four
# were found by BOOTING a role image rather than evaluating one, because none of
# them is an evaluation error: each simply leaves a unit failed, and one failed
# unit leaves the system `degraded` rather than `running` -- which would make
# `systemctl is-system-running` useless as a health check for every role.

{ config, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/docker-container.nix"
    ../my/system/oci-image/image.nix
  ];

  config = {
    # my.storage.impermanence is rejected in lib/mkSystem.nix's oci branch, not
    # here. An assertion could not do it: `assertions` is a list, the module
    # system forces the whole list before filtering to the failing ones, and
    # impermanence declares a `/persist` mount that a role has no filesystem
    # module to give a device -- so enabling it produced nixpkgs' own
    # `fileSystems."/persist".fsType was accessed but has no value defined` and
    # this message was never reached. secureBoot has no such side effect, so its
    # assertion below fires as written.
    assertions = [
      {
        assertion = !config.my.security.secureBoot.enable;
        message = ''
          my.security.secureBoot is not available in a role image: lanzaboote
          signs an EFI stub, and a container has no bootloader to hand it to.
        '';
      }
    ];

    # The docker-container profile is not one module. It also pulls in
    # installer/cd-dvd/channel.nix, profiles/minimal.nix and
    # profiles/clone-config.nix, and two of those change RUNTIME behaviour that
    # nothing here asked for:
    #
    #   * clone-config sets `installer.cloneConfig = true`, whose
    #     `boot.postBootCommands` -- which stage 2 runs in a container, every
    #     boot -- writes /etc/nixos/configuration.nix from a generated template
    #     whose `imports` are EMPTY. Inside a BUILDER, which carries nix and runs
    #     repository-supplied shell, a `nixos-rebuild` would then build an
    #     essentially blank NixOS rather than this role. A role is built from
    #     this repo and replaced, never rebuilt in place, so the file is a trap
    #     with no use.
    #
    #   * channel.nix installs a nixos channel a role never updates from.
    installer.cloneConfig = false;

    # WHAT A CONTAINER OVERRIDES RATHER THAN REFUSES.
    #
    # This variant must be applicable to ANY machine -- including a laptop with
    # disks, impermanence, users and a GPU. `nix build
    # .#nixosConfigurations.yoga.config.system.build.image` is an absurd thing
    # to want and it must still work, because that is what makes this an output
    # of a configuration rather than a privilege of purpose-built ones.
    #
    # So the shape here is qemu-vm.nix's: it does not reject a machine that has
    # real filesystems, it `mkVMOverride`s them. Rejection could not work even if
    # it were wanted -- `assertions` is a list, the module system forces the
    # whole list before filtering to the failing ones, so impermanence's
    # undefined `/persist` mount errors with nixpkgs' own message
    #
    #   The option `fileSystems."/persist".fsType' was accessed but has no value
    #
    # before any assertion of ours is read. That is why the old
    # `platform = "oci"` branch rejected in the CONSTRUCTOR instead, and why
    # removing the constructor means overriding here.
    #
    # Impermanence describes what survives a tmpfs root being wiped. A
    # container's root IS the image and nothing wipes it, so the question does
    # not arise; state a machine must keep is a volume declared by whatever
    # hosts it.

    # A ROLE IS ONE DOMAIN SWITCHED ON. Importing ./linux.nix wholesale is what
    # keeps my.infra.radicle working unchanged, and it is also how a role
    # inherits every default written for a WORKSTATION. Those defaults are not
    # inert: measured on a builder before this block, 61 units, and among them
    #
    #   * openrgb, defaulted true and ungated by my.theming.enable
    #     (my/theming/options.nix:82-85), running `openrgb --server` AS ROOT on
    #     port 6742 -- an I2C/SMBus control surface, in the one role that runs
    #     repository-supplied shell;
    #   * the whole audio stack, my.hardware.audio.enable defaulting true
    #     (my/hardware/options.nix:69-72): pipewire, pipewire-pulse,
    #     wireplumber, rtkit-daemon;
    #   * sshd, auto-enabled merely because a role turns tailscale on
    #     (my/network/openssh), which would put port 22 on tailscale0 in a
    #     builder the design says needs NO inbound reachability at all. Turning
    #     it off removes the port with it: my/network/openssh opens 22 only
    #     while sshd is actually running, so the two cannot drift apart.
    #
    # Each is hardware or administration a container does not have and cannot
    # use: there is no RGB device, no sound card, and a role is replaced by
    # rebuilding its image rather than logged into. Turned off HERE rather than
    # in roles/radicle because none of it is radicle-specific -- it is what
    # "a container" means, and the next role would inherit the same.
    my = {
      theming.openrgb.enable = lib.mkForce false;
      hardware.audio.enable = lib.mkForce false;
      network.openssh.enable = lib.mkForce false;

      # Impermanence describes what survives a tmpfs root being wiped. A
      # container's root IS the image and nothing wipes it, so the question does
      # not arise; state a machine must keep is a volume declared by whatever
      # hosts it. Forced rather than asserted because a variant is an output of
      # WHATEVER machine it is asked about -- including a laptop that uses
      # impermanence -- and an assertion could not fire anyway: `assertions` is
      # forced as a whole list, so impermanence's deviceless /persist mount
      # errors with nixpkgs' own message first. qemu-vm.nix mkVMOverrides
      # `fileSystems` for the same reason.
      storage.impermanence.enable = lib.mkForce false;

      # LET THE KERNEL PICK tailscaled's WireGuard port instead of taking the
      # fleet-wide default of 41641.
      #
      # A role is its own tailnet node with its own tailscaled, and a host runs
      # several of them beside its own. Rootless podman NATs through the host
      # and preserves source ports where it can, so every tailscaled defaulting
      # to 41641 means the first to claim it works and the rest do not --
      # reporting `magicsock: network down` and `UDP: false` while looking
      # entirely healthy: active, zero restarts, registration intact, nothing in
      # `systemctl --failed`. The only clue is one line in a DIFFERENT
      # container's log, `Couldn't open flow specific socket: Address already in
      # use`, and which node loses is decided by boot order, so it moves.
      #
      # 0 rather than a number assigned per role, because the port is not an
      # address: peers find a node through the control plane, and no config,
      # `connect` entry or URL ever names it. So there is nothing to coordinate
      # and nothing to keep in sync.
      network.tailscale.port = lib.mkForce 0;
    };
    services.openssh.enable = lib.mkForce false;

    # The nixpkgs registry pin is NOT from that profile -- it is nixpkgs' own
    # behaviour for any system built from a flake: misc/nixpkgs-flake.nix:94-95
    # sets `nix.registry.nixpkgs.to` whenever `nixpkgs.flake.source` is set,
    # which pins /etc/nix/registry.json at the sources the system was built
    # from and drags those ~330MB into the closure.
    #
    # On a workstation that is a feature -- `nix run nixpkgs#hello` reuses what
    # the system already has. In a role it is neither: nothing in a seed
    # evaluates nix at all, and a BUILDER runs jobs that carry their own
    # flake.lock, so a bare `nixpkgs#...` resolving to a snapshot that rode in
    # with the image is a difference between what the job asked for and what it
    # gets. setNixPath goes with it -- nixpkgs asserts it requires the registry
    # pin, and `<nixpkgs>` means as little here for the same reason.
    nixpkgs.flake = {
      setFlakeRegistry = false;
      setNixPath = false;
    };

    system = {
      # channel.nix's half of the above (system.installer.channel.enable:42,
      # nix.registry.nixpkgs.to:51). Switching it off also drops the bundled
      # nixpkgs SOURCE, which is the bulk of a role image -- but that is a side
      # effect here, not the reason: size work is deferred and belongs in its
      # own pass.
      installer.channel.enable = false;

      # A role keeps no state of its own -- everything it must remember is a
      # bind mount from whatever hosts the container, and the image itself is
      # rebuilt from this repo rather than upgraded in place. There is therefore
      # no older NixOS whose defaults a role has to stay compatible with, which
      # is the only thing stateVersion means. Pinned rather than tracking
      # `lib.trivial.release` so a nixpkgs bump cannot silently change a service
      # default underneath a running role; mkDefault so a role that DOES carry
      # legacy state can say so.
      stateVersion = lib.mkDefault "26.11";

      # HOST DEFAULT 1 of 4 -- /etc/machine-id, the mount case.
      #
      # systemd generates an ID when it finds none, but it writes the result to
      # /run/machine-id and BIND MOUNTS that over /etc/machine-id. That mount is
      # exactly what a role cannot do, so /etc/machine-id keeps the
      # "uninitialized" placeholder and every sd_id128_get_machine() answers
      # -ENOPKG. dbus-broker's launcher reports that, opaquely, as
      #
      #     ERROR launcher_run_child ...: Package not installed
      #     ERROR service_add ...: Transport endpoint is not connected
      #     Exiting due to fatal error: -107
      #
      # and then restarts forever, so the system bus never comes up at all.
      #
      # Seeding the ID during ACTIVATION removes the need for the mount: stage 2
      # runs before systemd is exec'd, and /etc is plainly writable there.
      # systemd-machine-id-setup derives the ID from the container UUID, so it
      # belongs to the CONTAINER and not to the image -- nothing identity-shaped
      # is baked in, and two containers off one image do not share an ID.
      activationScripts.machineId = {
        deps = [ "etc" ];
        text = "${config.systemd.package}/bin/systemd-machine-id-setup";
      };
    };

    # `my.boot.uefi` defaults to TRUE -- every real machine in this fleet boots
    # UEFI, so that default is right for a host and meaningless for a role.
    # Forced rather than defaulted because it is not a preference a container
    # can hold: `boot.isContainer` already removes the kernel and the initrd,
    # and leaving systemd-boot on collides with the docker-container profile's
    # own `system.build.installBootLoader` (only one bootloader may be defined).
    my.boot.uefi = lib.mkForce false;

    systemd = {
      # HOST DEFAULT 2 of 4 -- /run/wrappers, the other mount case.
      #
      # nixpkgs' wrappers module defines this as a tmpfs mount unconditionally
      # in its `config` block (security/wrappers/default.nix:307-318), and a
      # role cannot mount one:
      #
      #     mount: /run/wrappers: permission denied
      #
      # so the mount unit is masked -- a plain `enable = false` collides with
      # the definition systemd.nix already makes, hence mkForce -- and the
      # directory is provided by tmpfiles instead. The consequence for
      # suid-sgid-wrappers.service is handled under `services` below.
      #
      # The wrapper SET is deliberately left alone. Setuid does not take effect
      # on a plain directory, which costs a role nothing -- every radicle
      # service runs unprivileged under systemd's own confinement -- whereas
      # emptying it with `security.wrappers = mkForce { }` would delete wrappers
      # other modules declare and expect to exist, dbus' launch helper included.
      units."run-wrappers.mount".enable = lib.mkForce false;
      tmpfiles.rules = [ "d /run/wrappers 0755 root root -" ];

      # HOST DEFAULT 3 of 4 -- systemd-oomd, the step-USER case.
      #
      # A userspace OOM killer is whole-MACHINE memory policy: it watches PSI on
      # the cgroup tree and kills the worst offender. In a role that is the
      # host's job -- the host owns the memory the container is allowed, and a
      # killer inside would be acting on figures that are not its own. It also
      # cannot start here regardless, failing at step USER and taking
      # systemd-oomd.socket down with it. Forced because my/system/core sets it
      # unconditionally, which is right for the machines that was written for.
      oomd.enable = lib.mkForce false;

      services = {
        # Completes host default 2. suid-sgid-wrappers.service carries
        # `DefaultDependencies=false` and `After=systemd-sysusers.service`
        # alone, so with the mount gone it runs before anything has created the
        # directory and dies on `chmod: cannot access '/run/wrappers'`. Ordering
        # it after the tmpfiles run adds no cycle: both units are already
        # ordered before sysinit.target, and tmpfiles wants nothing of wrappers.
        suid-sgid-wrappers.after = [ "systemd-tmpfiles-setup.service" ];

        # HOST DEFAULT 4 of 4 -- nscd, the other step-USER case.
        #
        # nsncd is the reason a role can resolve `systemd-*` accounts at all:
        # /etc/nsswitch.conf names the `systemd` and `mymachines` NSS modules,
        # and glibc reaches them only through the daemon. So it is KEPT, and the
        # one directive that stops it starting is dropped instead --
        # `RestrictSUIDSGID=` is a seccomp filter, nsncd runs as `User=nscd`,
        # and that pairing is the step-USER case. Established by elimination in
        # a booted role: with the filter off and every `Protect*` still in
        # place, nsncd starts and answers.
        #
        # Turning nscd OFF is the obvious-looking alternative and it is the
        # wrong trade. nixpkgs then asserts `system.nssModules = mkForce [ ]`,
        # which empties the LD_LIBRARY_PATH dbus and every other NSS consumer is
        # handed while leaving nsswitch.conf still naming modules that nothing
        # can then load.
        #
        # The filter itself costs a role nothing: nsncd creates no files, and
        # the binary is not setuid to begin with.
        nscd.serviceConfig.RestrictSUIDSGID = lib.mkForce false;

        # THE FIREWALL IS NOT DISABLED, AND THIS UNIT IS WHY THAT IS SAFE.
        #
        # A role states its reachability the same way a host does: nothing sets
        # `openFirewall`, and my/infra/radicle scopes the node and httpd ports to
        # tailscale0 through my.network.tailscale.allowedTCPPorts. A feature that
        # needs a port open is the thing that opens it. That stance is only worth
        # anything if the packet filter actually loads.
        #
        # It silently might not. firewall.service carries
        # `ConditionCapability = "CAP_NET_ADMIN"` (nixpkgs
        # services/networking/firewall-iptables.nix:353), and systemd SKIPS a
        # unit whose condition is unmet rather than failing it. Rootless podman's
        # default bounding set has no NET_ADMIN, so the role comes up reporting
        # `running`, with ZERO failed units, an empty ruleset, and every port its
        # services listen on reachable from anywhere the container can be
        # reached. Measured: `ConditionResult=no`, `iptables -S` empty.
        #
        # That is the one failure mode the rest of this file cannot catch,
        # because it is the one that does not leave a unit failed. So it is
        # turned into a failure here. The role still needs NET_ADMIN (tailscaled
        # needs it too, and it is grantable rootless -- unlike SYS_ADMIN, which
        # is refused on purpose because a builder runs repository-supplied
        # shell); what this removes is the possibility of not noticing.
        firewall-enforced = {
          description = "Assert the packet filter actually loaded";
          after = [ "firewall.service" ];
          wants = [ "firewall.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if ${config.systemd.package}/bin/systemctl is-active --quiet firewall.service; then
              exit 0
            fi
            echo "firewall.service did not run: $(${config.systemd.package}/bin/systemctl show firewall.service -p ConditionResult --value)" >&2
            echo "" >&2
            echo "It is conditioned on CAP_NET_ADMIN, which this container was not" >&2
            echo "given, so systemd skipped it and no rules are loaded. Every port" >&2
            echo "this role listens on is reachable, including the ones scoped to" >&2
            echo "tailscale0 in the config." >&2
            echo "" >&2
            echo "Run the container with --cap-add=NET_ADMIN --cap-add=NET_RAW" >&2
            echo "--device=/dev/net/tun. tailscaled needs the same." >&2
            exit 1
          '';
        };
      };
    };
  };
}
