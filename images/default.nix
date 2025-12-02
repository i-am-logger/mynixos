{ pkgs }:

let
  # Import nixpkgs with only CodeQL allowed as unfree
  pkgsUnfree = import pkgs.path {
    system = pkgs.stdenv.system;
    config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
      "codeql"
    ];
  };

  # Entry point script for the container
  entrypoint = pkgs.writeShellScript "runner-entrypoint" ''
    set -e
    
    # Required environment variables:
    # - RUNNER_NAME: Name of the runner
    # - RUNNER_TOKEN: GitHub registration token (provided by ARC)
    # - GITHUB_URL: GitHub repository/org URL
    
    export RUNNER_ALLOW_RUNASROOT=1
    export HOME=/root
    
    # Initialize runner directory with correct permissions
    if [ ! -d "/runner" ]; then
      mkdir -p /runner
      cd /runner
      
      # Copy runner files to writable location
      cp -r ${pkgs.github-runner}/* .
      chmod +x *.sh
      
      echo "Configuring runner..."
      ./config.sh \
        --unattended \
        --url "''${GITHUB_URL}" \
        --token "''${RUNNER_TOKEN}" \
        --name "''${RUNNER_NAME:-$(hostname)}" \
        --work _work \
        --labels "nixos,nix" \
        --ephemeral
    fi
    
    cd /runner
    # Run the runner
    echo "Starting runner..."
    exec ./run.sh
  '';

in
pkgs.dockerTools.buildLayeredImage {
  name = "github-runner";
  tag = "nixos-latest";

  contents = pkgs.buildEnv {
    name = "github-runner-env";
    paths = with pkgs; [
      # Core system
      busybox
      coreutils
      bash
      cacert
      tzdata

      # Git and VCS
      git

      # GitHub Actions Runner
      github-runner

      # Nix for builds (already includes nixpkgs-fmt)
      nix
      nixpkgs-fmt

      # Build tools (frequently installed in workflows)
      gcc
      gnumake
      pkg-config
      automake
      autoconf
      libtool
      cmake

      # Rust toolchain (used by pds project)
      rustc
      cargo
      rustfmt
      clippy

      # Node.js (used for MCP servers and some actions)
      nodejs_20

      # GitHub CLI (installed in every pds workflow)
      gh

      # CodeQL (for GitHub Copilot coding agent - unfree license)
      pkgsUnfree.codeql

      # Docker CLI (for workflows that need docker)
      docker-client

      # Network tools
      curl
      wget
      openssh

      # Archive/compression tools (xz-utils needed by magic-nix-cache)
      gnutar
      gzip
      xz
      unzip
      zip
      bzip2

      # Text processing utilities
      jq
      yq-go
      findutils
      gawk
      gnugrep
      gnused

      # System utilities
      which
      file
      procps

      # CA certificates update tool
      nssTools

      # Essential libraries
      openssl
      openssl.dev
      zlib
      libxml2
      libxslt
      sqlite

      # Common dev dependencies
      pkg-config
      stdenv.cc.cc.lib
    ];
  };

  fakeRootCommands = ''
        # Create system directories
        mkdir -p {etc,tmp,var,root,runner}
        mkdir -p {nix/var/nix,var/lib}
        mkdir -p {sbin,usr/sbin}
    
        # Create /usr/bin for compatibility (some scripts expect /usr/bin/env)
        mkdir -p usr/bin
        ln -sf ${pkgs.coreutils}/bin/env usr/bin/env
    
        # Create minimal /etc files
        cat > etc/passwd << EOF
    root:x:0:0:root:/root:${pkgs.bash}/bin/bash
    nobody:x:65534:65534:nobody:/:/bin/false
    EOF
    
        cat > etc/group << EOF
    root:x:0:
    nogroup:x:65534:
    EOF
    
        # Set up Nix configuration
        mkdir -p etc/nix
        cat > etc/nix/nix.conf << EOF
    experimental-features = nix-command flakes
    sandbox = false
    filter-syscalls = false
    build-users-group =
    EOF
    
        # Set permissions
        chmod 755 runner tmp usr/bin sbin usr/sbin
        chmod 644 etc/passwd etc/group
  '';

  config = {
    Cmd = [ "${entrypoint}" ];
    WorkingDir = "/runner";
    Env = [
      "PATH=/bin:/usr/bin:/sbin:/usr/sbin"
      "NIX_PATH=nixpkgs=${pkgs.path}"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "RUNNER_ALLOW_RUNASROOT=1"
      "HOME=/root"
      "SHELL=${pkgs.bash}/bin/bash"
      "GITHUB_HOST=github.com"
    ];
    User = "root";
  };
}
