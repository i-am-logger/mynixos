{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs specialArgs baseModules baseConfig;

  # Evaluate a NixOS system with the mynixos module and given config.
  # Returns the raw evaluation result (not a derivation).
  evalWithConfig = testConfig:
    lib.nixosSystem {
      inherit specialArgs;
      modules = baseModules ++ [ baseConfig testConfig ];
    };

  # Build a check derivation that verifies evaluation with bad config fails.
  # NixOS evaluates options lazily, so we pass an accessor function that
  # reads the specific option expected to fail type validation.
  #
  # The accessor is FIRST run against a valid config. Without that step any
  # evaluation failure counts as a pass -- including "the option does not
  # exist" -- so deleting an option would silently turn its rejection tests
  # green instead of red. That is exactly the failure this suite must not have,
  # because deleting options is what the refactors here keep doing.
  # `controlConfig` is a VALID config of the same shape as the invalid one, used
  # only to prove the accessor can read the option at all. It defaults to a bare
  # host; tests whose option lives under a constructed user must pass one that
  # constructs that user, or the control fails for the wrong reason.
  mustReject' = controlConfig: name: accessor: testConfig:
    let
      control = builtins.tryEval
        (builtins.deepSeq (accessor (evalWithConfig controlConfig).config) "ok");
      result = builtins.tryEval (builtins.deepSeq (accessor (evalWithConfig testConfig).config) "ok");
    in
    pkgs.runCommand "type-validation-${name}" { } (
      if !control.success then
        builtins.throw
          ("FAIL: ${name} cannot even read the option under a VALID config -- "
            + "the option was probably renamed or deleted, so this check was passing for the wrong reason")
      else if result.success then
        builtins.throw "FAIL: should have rejected invalid config for ${name}"
      else ''
        echo "PASS: correctly rejected invalid config for ${name}"
        touch $out
      ''
    );

  mustReject = mustReject' { networking.hostName = "control"; };

  # Build a check derivation that verifies evaluation with valid config succeeds.
  mustAccept = name: accessor: testConfig:
    let
      eval = evalWithConfig testConfig;
      value = builtins.deepSeq (accessor eval.config) "ok";
    in
    pkgs.runCommand "type-validation-${name}" { } ''
      echo "PASS: correctly accepted valid config for ${name} (value: ${value})"
      touch $out
    '';

  # mkSystem's `platform`. It is a plain FUNCTION argument, not an option, so
  # mustReject -- which evaluates a NixOS config -- cannot express it. The
  # discipline is kept unchanged though: a VALID platform is read first, so
  # "mkSystem throws for every input" cannot masquerade as "the bad value was
  # rejected". Same failure mode as an option that was renamed away, same fix.
  #
  # The enum is closed on purpose. `platform = "vm"` is a designed-for future
  # branch and is REJECTED BY NAME until it exists, because the alternative --
  # falling through to a default -- builds the wrong kind of machine in silence.
  role = platform: self.lib.mkSystem {
    inherit platform;
    hostname = "type-validation-role";
    system = "x86_64-linux";
  };

  platformRejects = name: badPlatform:
    let
      read = platform: builtins.tryEval
        (builtins.deepSeq (role platform).config.networking.hostName "ok");
      control = read "oci";
      result = read badPlatform;
    in
    pkgs.runCommand "type-validation-${name}" { } (
      if !control.success then
        builtins.throw
          ("FAIL: ${name} cannot build a system with a VALID platform -- "
            + "mkSystem's oci branch is broken, so this check was passing for the wrong reason")
      else if result.success then
        builtins.throw "FAIL: should have rejected platform '${badPlatform}'"
      else ''
        echo "PASS: correctly rejected platform '${badPlatform}'"
        touch $out
      ''
    );

in
{
  # --- Enum-by-dispatch: mkSystem's `platform` ---

  platform-rejects-unknown = platformRejects "platform-rejects-unknown" "container";

  platform-rejects-unimplemented = platformRejects "platform-rejects-unimplemented" "vm";

  # --- String type: my.system.hostname ---

  hostname-rejects-int = mustReject "hostname-rejects-int"
    (c: c.my.system.hostname)
    { networking.hostName = "test"; my.system.hostname = 42; };

  hostname-accepts-string = mustAccept "hostname-accepts-string"
    (c: c.my.system.hostname)
    { networking.hostName = "test"; my.system.hostname = "valid-hostname"; };

  hostname-accepts-null = mustAccept "hostname-accepts-null"
    (c: c.my.system.hostname)
    { networking.hostName = "test"; my.system.hostname = null; };

  # --- Bool type: my.system.enable ---

  system-enable-rejects-string = mustReject "system-enable-rejects-string"
    (c: c.my.system.enable)
    { networking.hostName = "test"; my.system.enable = "yes"; };

  system-enable-accepts-bool = mustAccept "system-enable-accepts-bool"
    (c: c.my.system.enable)
    { networking.hostName = "test"; my.system.enable = true; };

  # --- Int range: my.performance.zramPercent (0-100) ---

  zram-rejects-string = mustReject "zram-rejects-string"
    (c: c.my.performance.zramPercent)
    { networking.hostName = "test"; my.performance.zramPercent = "fifty"; };

  zram-rejects-negative = mustReject "zram-rejects-negative"
    (c: c.my.performance.zramPercent)
    { networking.hostName = "test"; my.performance.zramPercent = -1; };

  zram-rejects-over-100 = mustReject "zram-rejects-over-100"
    (c: c.my.performance.zramPercent)
    { networking.hostName = "test"; my.performance.zramPercent = 101; };

  zram-accepts-valid-int = mustAccept "zram-accepts-valid-int"
    (c: c.my.performance.zramPercent)
    { networking.hostName = "test"; my.performance.zramPercent = 50; };

  zram-accepts-zero = mustAccept "zram-accepts-zero"
    (c: c.my.performance.zramPercent)
    { networking.hostName = "test"; my.performance.zramPercent = 0; };

  zram-accepts-100 = mustAccept "zram-accepts-100"
    (c: c.my.performance.zramPercent)
    { networking.hostName = "test"; my.performance.zramPercent = 100; };

  # --- Enum: my.hardware.cpu (null | "amd" | "intel") ---

  cpu-rejects-invalid-enum = mustReject "cpu-rejects-invalid-enum"
    (c: c.my.hardware.cpu)
    { networking.hostName = "test"; my.hardware.cpu = "arm"; };

  cpu-rejects-int = mustReject "cpu-rejects-int"
    (c: c.my.hardware.cpu)
    { networking.hostName = "test"; my.hardware.cpu = 123; };

  cpu-accepts-amd = mustAccept "cpu-accepts-amd"
    (c: c.my.hardware.cpu)
    { networking.hostName = "test"; my.hardware.cpu = "amd"; };

  cpu-accepts-intel = mustAccept "cpu-accepts-intel"
    (c: c.my.hardware.cpu)
    { networking.hostName = "test"; my.hardware.cpu = "intel"; };

  cpu-accepts-null = mustAccept "cpu-accepts-null"
    (c: c.my.hardware.cpu)
    { networking.hostName = "test"; my.hardware.cpu = null; };

  # --- Enum: my.hardware.gpu (null | "amd" | "nvidia" | "intel") ---

  gpu-rejects-invalid-enum = mustReject "gpu-rejects-invalid-enum"
    (c: c.my.hardware.gpu)
    { networking.hostName = "test"; my.hardware.gpu = "matrox"; };

  gpu-rejects-bool = mustReject "gpu-rejects-bool"
    (c: c.my.hardware.gpu)
    { networking.hostName = "test"; my.hardware.gpu = true; };

  gpu-accepts-amd = mustAccept "gpu-accepts-amd"
    (c: c.my.hardware.gpu)
    { networking.hostName = "test"; my.hardware.gpu = "amd"; };

  gpu-accepts-nvidia = mustAccept "gpu-accepts-nvidia"
    (c: c.my.hardware.gpu)
    { networking.hostName = "test"; my.hardware.gpu = "nvidia"; };

  gpu-accepts-intel = mustAccept "gpu-accepts-intel"
    (c: c.my.hardware.gpu)
    { networking.hostName = "test"; my.hardware.gpu = "intel"; };

  gpu-accepts-null = mustAccept "gpu-accepts-null"
    (c: c.my.hardware.gpu)
    { networking.hostName = "test"; my.hardware.gpu = null; };

  # --- Enum: my.system.architecture (null | "x86_64-linux" | "aarch64-linux") ---

  arch-rejects-invalid-enum = mustReject "arch-rejects-invalid-enum"
    (c: c.my.system.architecture)
    { networking.hostName = "test"; my.system.architecture = "armv7l-linux"; };

  arch-accepts-x86 = mustAccept "arch-accepts-x86"
    (c: c.my.system.architecture)
    { networking.hostName = "test"; my.system.architecture = "x86_64-linux"; };

  arch-accepts-aarch64 = mustAccept "arch-accepts-aarch64"
    (c: c.my.system.architecture)
    { networking.hostName = "test"; my.system.architecture = "aarch64-linux"; };

  arch-accepts-null = mustAccept "arch-accepts-null"
    (c: c.my.system.architecture)
    { networking.hostName = "test"; my.system.architecture = null; };

  # --- Enum: my.filesystem.type (null | "disko" | "nixos") ---

  filesystem-type-rejects-invalid = mustReject "filesystem-type-rejects-invalid"
    (c: c.my.filesystem.type)
    { networking.hostName = "test"; my.filesystem.type = "zfs"; };

  filesystem-type-accepts-disko = mustAccept "filesystem-type-accepts-disko"
    (c: c.my.filesystem.type)
    { networking.hostName = "test"; my.filesystem.type = "disko"; };

  filesystem-type-accepts-nixos = mustAccept "filesystem-type-accepts-nixos"
    (c: c.my.filesystem.type)
    { networking.hostName = "test"; my.filesystem.type = "nixos"; };

  filesystem-type-accepts-null = mustAccept "filesystem-type-accepts-null"
    (c: c.my.filesystem.type)
    { networking.hostName = "test"; my.filesystem.type = null; };

  # --- Int range: my.hardware.cooling...lcd.brightness (0-100) ---

  lcd-brightness-rejects-string = mustReject "lcd-brightness-rejects-string"
    (c: c.my.hardware.cooling.nzxt.kraken-elite-rgb.elite-240-rgb.lcd.brightness)
    { networking.hostName = "test"; my.hardware.cooling.nzxt.kraken-elite-rgb.elite-240-rgb.lcd.brightness = "bright"; };

  lcd-brightness-rejects-over-100 = mustReject "lcd-brightness-rejects-over-100"
    (c: c.my.hardware.cooling.nzxt.kraken-elite-rgb.elite-240-rgb.lcd.brightness)
    { networking.hostName = "test"; my.hardware.cooling.nzxt.kraken-elite-rgb.elite-240-rgb.lcd.brightness = 150; };

  lcd-brightness-accepts-valid = mustAccept "lcd-brightness-accepts-valid"
    (c: c.my.hardware.cooling.nzxt.kraken-elite-rgb.elite-240-rgb.lcd.brightness)
    { networking.hostName = "test"; my.hardware.cooling.nzxt.kraken-elite-rgb.elite-240-rgb.lcd.brightness = 75; };

  # --- Bool type: my.graphical.enable ---

  graphical-enable-rejects-string = mustReject "graphical-enable-rejects-string"
    (c: c.my.graphical.enable)
    { networking.hostName = "test"; my.graphical.enable = "true"; };

  graphical-enable-accepts-bool = mustAccept "graphical-enable-accepts-bool"
    (c: c.my.graphical.enable)
    { networking.hostName = "test"; my.graphical.enable = lib.mkForce true; };

  # --- List type: my.system.allowedUnfreePackages ---

  unfree-rejects-string = mustReject "unfree-rejects-string"
    (c: c.my.system.allowedUnfreePackages)
    { networking.hostName = "test"; my.system.allowedUnfreePackages = "not-a-list"; };

  unfree-rejects-list-of-int = mustReject "unfree-rejects-list-of-int"
    (c: c.my.system.allowedUnfreePackages)
    { networking.hostName = "test"; my.system.allowedUnfreePackages = [ 1 2 3 ]; };

  unfree-accepts-list-of-string = mustAccept "unfree-accepts-list-of-string"
    (c: c.my.system.allowedUnfreePackages)
    { networking.hostName = "test"; my.system.allowedUnfreePackages = [ "steam" "nvidia-x11" ]; };

  unfree-accepts-empty-list = mustAccept "unfree-accepts-empty-list"
    (c: c.my.system.allowedUnfreePackages)
    { networking.hostName = "test"; my.system.allowedUnfreePackages = [ ]; };

  # --- String type: my.storage.impermanence.persistPath ---

  persist-path-rejects-int = mustReject "persist-path-rejects-int"
    (c: c.my.storage.impermanence.persistPath)
    { networking.hostName = "test"; my.storage.impermanence.persistPath = 42; };

  persist-path-accepts-string = mustAccept "persist-path-accepts-string"
    (c: c.my.storage.impermanence.persistPath)
    { networking.hostName = "test"; my.storage.impermanence.persistPath = "/mnt/persist"; };

  # --- Bool type: my.hardware.bluetooth.enable ---

  bluetooth-rejects-string = mustReject "bluetooth-rejects-string"
    (c: c.my.hardware.bluetooth.enable)
    { networking.hostName = "test"; my.hardware.bluetooth.enable = "yes"; };

  bluetooth-accepts-bool = mustAccept "bluetooth-accepts-bool"
    (c: c.my.hardware.bluetooth.enable)
    { networking.hostName = "test"; my.hardware.bluetooth.enable = false; };

  # --- Enum: my.environment.login (backend + look) ---

  login-backend-rejects-invalid = mustReject "login-backend-rejects-invalid"
    (c: c.my.environment.login.backend)
    { networking.hostName = "test"; my.environment.login.backend = "startx"; };

  login-backend-accepts-greetd = mustAccept "login-backend-accepts-greetd"
    (c: c.my.environment.login.backend)
    { networking.hostName = "test"; my.environment.login.backend = "greetd"; };

  login-backend-accepts-sddm = mustAccept "login-backend-accepts-sddm"
    (c: c.my.environment.login.backend)
    { networking.hostName = "test"; my.environment.login.backend = "sddm"; };

  login-look-rejects-invalid = mustReject "login-look-rejects-invalid"
    (c: c.my.environment.login.look)
    { networking.hostName = "test"; my.environment.login.look = "regreet"; };

  # --- Enum: my.dev.containers.backend ---
  #
  # An enum and not two booleans, because podman's dockerCompat/dockerSocket and
  # dockerd both claim the `docker` binary and /run/docker.sock. A third value
  # would have to name a runtime that is actually wired up.

  containers-backend-rejects-invalid = mustReject "containers-backend-rejects-invalid"
    (c: c.my.dev.containers.backend)
    { networking.hostName = "test"; my.dev.containers.backend = "containerd"; };

  containers-backend-rejects-bool = mustReject "containers-backend-rejects-bool"
    (c: c.my.dev.containers.backend)
    { networking.hostName = "test"; my.dev.containers.backend = true; };

  containers-backend-accepts-podman = mustAccept "containers-backend-accepts-podman"
    (c: c.my.dev.containers.backend)
    { networking.hostName = "test"; my.dev.containers.backend = "podman"; };

  containers-backend-accepts-docker = mustAccept "containers-backend-accepts-docker"
    (c: c.my.dev.containers.backend)
    { networking.hostName = "test"; my.dev.containers.backend = "docker"; };

  containers-backend-defaults-to-podman = mustAccept "containers-backend-defaults-to-podman"
    (c:
      if c.my.dev.containers.backend == "podman" then "ok"
      else builtins.throw "my.dev.containers.backend should default to podman on Linux")
    { networking.hostName = "test"; };

  # --- Persistence path validation (relativePath type) ---

  persistence-rejects-absolute-path =
    mustReject'
      {
        networking.hostName = "control";
        my.users.test.apps.terminal.shells.bash.persistedFiles = [ ".bash_history" ];
      }
      "persistence-rejects-absolute-path"
      (c: c.my.users.test.apps.terminal.shells.bash.persistedFiles)
      {
        networking.hostName = "test";
        my.users.test.apps.terminal.shells.bash.persistedFiles = [ "/etc/passwd" ];
      };

  persistence-rejects-dotdot =
    mustReject'
      {
        networking.hostName = "control";
        my.users.test.apps.terminal.shells.bash.persistedDirectories = [ ".bash_history" ];
      }
      "persistence-rejects-dotdot"
      (c: c.my.users.test.apps.terminal.shells.bash.persistedDirectories)
      {
        networking.hostName = "test";
        my.users.test.apps.terminal.shells.bash.persistedDirectories = [ "../../etc" ];
      };

  # --- Distributed enum: my.users.<n>.graphical.shell ---
  # Two declarations merge (base "none"; the vogix theming module contributes
  # "vogix" and owns the gate-computed default). Anything outside the union is
  # a type error — including "waybar", whose module is deleted: the fleet's
  # shell is the vogix desktop.
  graphical-shell-rejects-unknown = mustReject'
    {
      networking.hostName = "control";
      my.users.test.graphical.shell = "none";
    }
    "graphical-shell-rejects-unknown"
    (c: c.my.users.test.graphical.shell)
    {
      networking.hostName = "test";
      my.users.test.graphical.shell = "gnome";
    };

  graphical-shell-rejects-waybar = mustReject'
    {
      networking.hostName = "control";
      my.users.test.graphical.shell = "none";
    }
    "graphical-shell-rejects-waybar"
    (c: c.my.users.test.graphical.shell)
    {
      networking.hostName = "test";
      my.users.test.graphical.shell = "waybar";
    };

  graphical-shell-accepts-none = mustAccept "graphical-shell-accepts-none"
    (c: c.my.users.test.graphical.shell)
    {
      networking.hostName = "test";
      my.users.test.graphical.shell = "none";
    };

  # The gate-computed default: a plain graphical user under the default
  # theming state (system theming on, the per-user injector defaulting
  # theming.vogix on) lands on the vogix shell; with the system gates off,
  # the same user lands on "none" — never on a missing renderer.
  graphical-shell-defaults-to-vogix = mustAccept "graphical-shell-defaults-to-vogix"
    (c:
      assert c.my.users.test.graphical.shell == "vogix";
      c.my.users.test.graphical.shell)
    {
      networking.hostName = "test";
      my.users.test = {
        fullName = "Test User";
        graphical.enable = true;
      };
    };

  graphical-shell-defaults-to-none-without-theming = mustAccept "graphical-shell-defaults-to-none-without-theming"
    (c:
      assert c.my.users.test.graphical.shell == "none";
      c.my.users.test.graphical.shell)
    {
      networking.hostName = "test";
      my.theming.enable = false;
      my.users.test = {
        fullName = "Test User";
        graphical.enable = true;
      };
    };

  # -------------------------------------------------------------------------
  # my.infra.radicle
  # -------------------------------------------------------------------------

  radicle-rejects-bad-seeding-policy = mustReject "radicle-rejects-bad-seeding-policy"
    (c: c.my.infra.radicle.node.defaultSeedingPolicy)
    {
      networking.hostName = "test";
      my.infra.radicle.node.defaultSeedingPolicy = "sometimes";
    };

  radicle-rejects-nonlist-connect = mustReject "radicle-rejects-nonlist-connect"
    (c: c.my.infra.radicle.node.connect)
    {
      networking.hostName = "test";
      my.infra.radicle.node.connect = "z6Mk@host:8776";
    };

  # mustReject' with a control that defines a VALID one-element list: the
  # default control leaves the list EMPTY, so `map (r: r.rid) []` would never
  # touch `rid` and a renamed sub-option would still look "rejected".
  radicle-rejects-mirror-repo-missing-rid = mustReject'
    {
      networking.hostName = "control";
      my.infra.radicle.mirror.repos = [{ rid = "rad:z2y"; githubRepo = "a/b"; }];
    }
    "radicle-rejects-mirror-repo-missing-rid"
    (c: map (r: r.rid) c.my.infra.radicle.mirror.repos)
    {
      networking.hostName = "test";
      my.infra.radicle.mirror.repos = [{ githubRepo = "a/b"; }];
    };

  radicle-rejects-bad-seed-scope = mustReject'
    {
      networking.hostName = "control";
      my.infra.radicle.seedRepositories = [{ rid = "rad:z2y"; scope = "all"; }];
    }
    "radicle-rejects-bad-seed-scope"
    (c: map (r: r.scope) c.my.infra.radicle.seedRepositories)
    {
      networking.hostName = "test";
      my.infra.radicle.seedRepositories = [{ rid = "rad:z2y"; scope = "everything"; }];
    };

  remote-builders-rejects-missing-hostkey = mustReject'
    {
      networking.hostName = "control";
      my.dev.remoteBuilders = [{
        hostName = "mac.example.ts.net";
        systems = [ "aarch64-darwin" ];
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQQo=";
      }];
    }
    "remote-builders-rejects-missing-hostkey"
    (c: map (b: b.publicHostKey) c.my.dev.remoteBuilders)
    {
      networking.hostName = "test";
      my.dev.remoteBuilders = [{
        hostName = "mac.example.ts.net";
        systems = [ "aarch64-darwin" ];
      }];
    };
}
