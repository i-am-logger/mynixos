{ inputs, lib, nixpkgs }:

{
  mkInstallerISO =
    { volumeID ? "NIXOS_INSTALLER"
    , supportedSystems ? [ ]
    , # List of system names this ISO supports (for documentation)
      extraPackages ? [ ]
    , extraConfig ? { }
    }:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        # Base installation CD configuration
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

        # Installer configuration
        {
          # ISO identity
          isoImage = {
            inherit volumeID;
            # Compression for smaller ISO
            squashfsCompression = "zstd -Xcompression-level 15";
          };

          # Enable flakes and experimental features
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          # Essential tools for installation
          environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
            # Version control
            git
            gh

            # Disk management
            gptfdisk
            parted

            # File systems
            btrfs-progs
            e2fsprogs
            dosfstools
            ntfs3g

            # Network tools
            curl
            wget

            # Text editors
            vim
            nano

            # System tools
            util-linux
            pciutils
            usbutils

            # Convenience
            tmux
            htop
            tree
          ] ++ extraPackages;

          # Enable SSH for remote installation
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          # Automatic network configuration
          networking.wireless.enable = false;
          networking.networkmanager.enable = true;

          # Generate README with supported systems
          environment.etc."nixos-installer/README.md" = lib.mkIf (supportedSystems != [ ]) {
            text = ''
              NixOS System Installer
              ======================

              This ISO can install or update the following systems:
              ${lib.concatMapStringsSep "\n" (sys: "- ${sys}") supportedSystems}

              Quick Start
              -----------

              1. Ensure network connectivity:
                 sudo systemctl start NetworkManager
                 nmtui  # For WiFi configuration

              2. Clone the configuration repository:
                 git clone <your-repo-url> /tmp/nixos-config

              3. Run the installer:
                 cd /tmp/nixos-config
                 sudo ./install.sh <system-name> install

              Fresh Installation vs Update
              ----------------------------

              The installer automatically detects:
              - If running from live ISO -> Fresh installation
              - If running on existing NixOS -> Update/rebuild

              For Updates on Existing Systems
              --------------------------------

              If you booted this ISO to repair/update an existing installation:

              1. Mount your existing system:
                 mount /dev/nvme0n1p3 /mnt  # Adjust partition as needed
                 mount /dev/nvme0n1p1 /mnt/boot

              2. Enter the system:
                 nixos-enter

              3. Navigate to your config and rebuild:
                 cd /etc/nixos
                 nixos-rebuild switch --flake .#<system-name>

              SSH Access
              ----------

              Root has no password by default. Set one to enable SSH:
                 passwd

              Then connect from another machine:
                 ssh root@<ip-address>
            '';
            mode = "0644";
          };

          # Set a welcome message
          programs.bash.shellInit = ''
            cat << 'EOF'

            ╔═══════════════════════════════════════════════════════════╗
            ║           NixOS System Installer Live ISO                ║
            ║                                                           ║
            ║  ${lib.optionalString (supportedSystems != [ ]) "Supports: ${lib.concatStringsSep ", " supportedSystems}"}
            ║  Mode: Fresh Install or System Update/Repair             ║
            ╚═══════════════════════════════════════════════════════════╝

            Quick start:
              1. Check network: nmtui (for WiFi)
              2. Read instructions: cat /etc/nixos-installer/README.md
              3. Clone repo and run installer

            For SSH access: passwd (root has no password by default)

            EOF
          '';

          # Allow empty root password for live ISO convenience
          users.users.root.password = "";
        }

        # Additional user configuration
        extraConfig
      ];
    };
}
