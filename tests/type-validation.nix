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
  mustReject = name: accessor: testConfig:
    let
      eval = evalWithConfig testConfig;
      result = builtins.tryEval (builtins.deepSeq (accessor eval.config) "ok");
    in
    pkgs.runCommand "type-validation-${name}" { } (
      if !result.success then ''
        echo "PASS: correctly rejected invalid config for ${name}"
        touch $out
      '' else
        builtins.throw "FAIL: should have rejected invalid config for ${name}"
    );

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

in
{
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

  # --- Enum: my.environment.displayManager.type ---

  display-manager-rejects-invalid = mustReject "display-manager-rejects-invalid"
    (c: c.my.environment.displayManager.type)
    { networking.hostName = "test"; my.environment.displayManager.type = "startx"; };

  display-manager-accepts-greetd = mustAccept "display-manager-accepts-greetd"
    (c: c.my.environment.displayManager.type)
    { networking.hostName = "test"; my.environment.displayManager.type = "greetd"; };

  display-manager-accepts-sddm = mustAccept "display-manager-accepts-sddm"
    (c: c.my.environment.displayManager.type)
    { networking.hostName = "test"; my.environment.displayManager.type = "sddm"; };

  # --- Persistence path validation (relativePath type) ---

  persistence-rejects-absolute-path = mustReject "persistence-rejects-absolute-path"
    (c: c.my.users.test.apps.terminal.shells.bash.persistedFiles)
    {
      networking.hostName = "test";
      my.users.test.apps.terminal.shells.bash.persistedFiles = [ "/etc/passwd" ];
    };

  persistence-rejects-dotdot = mustReject "persistence-rejects-dotdot"
    (c: c.my.users.test.apps.terminal.shells.bash.persistedDirectories)
    {
      networking.hostName = "test";
      my.users.test.apps.terminal.shells.bash.persistedDirectories = [ "../../etc" ];
    };
}
