{ pkgs }:

pkgs.testers.nixosTest {
  name = "github-runner-image-test";

  nodes.machine = { config, pkgs, ... }: {
    virtualisation = {
      diskSize = 8192;
      memorySize = 2048;
      docker.enable = true;
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("docker.service")
    
    # Load the runner image (this may take a while for the 3GB image)
    print("Loading GitHub runner image (3GB compressed, may take 1-2 minutes)...")
    image_path = "${import ./. { inherit pkgs; }}"
    print(f"Image path: {image_path}")
    machine.succeed(f"docker load < {image_path}", timeout=180)
    
    # Verify image was loaded
    print("Verifying image was loaded...")
    machine.succeed("docker images | grep github-runner")
    
    # Test 1: Check core utilities exist
    print("\n=== Test 1: Core Utilities ===")
    machine.succeed("docker run --rm github-runner:nixos-latest bash --version")
    machine.succeed("docker run --rm github-runner:nixos-latest git --version")
    machine.succeed("docker run --rm github-runner:nixos-latest which curl")
    machine.succeed("docker run --rm github-runner:nixos-latest which wget")
    
    # Test 2: Check Nix is installed and working
    print("\n=== Test 2: Nix ===")
    machine.succeed("docker run --rm github-runner:nixos-latest nix --version")
    machine.succeed("docker run --rm github-runner:nixos-latest nixpkgs-fmt --version")
    
    # Test 3: Check build tools
    print("\n=== Test 3: Build Tools ===")
    machine.succeed("docker run --rm github-runner:nixos-latest gcc --version")
    machine.succeed("docker run --rm github-runner:nixos-latest make --version")
    machine.succeed("docker run --rm github-runner:nixos-latest cmake --version")
    machine.succeed("docker run --rm github-runner:nixos-latest pkg-config --version")
    
    # Test 4: Check Rust toolchain
    print("\n=== Test 4: Rust Toolchain ===")
    machine.succeed("docker run --rm github-runner:nixos-latest rustc --version")
    machine.succeed("docker run --rm github-runner:nixos-latest cargo --version")
    machine.succeed("docker run --rm github-runner:nixos-latest rustfmt --version")
    machine.succeed("docker run --rm github-runner:nixos-latest cargo clippy --version")
    
    # Test 5: Check Node.js
    print("\n=== Test 5: Node.js ===")
    node_version = machine.succeed("docker run --rm github-runner:nixos-latest node --version").strip()
    print(f"Node.js version: {node_version}")
    assert node_version.startswith("v20"), f"Expected Node.js v20.x, got {node_version}"
    machine.succeed("docker run --rm github-runner:nixos-latest npm --version")
    
    # Test 6: Check GitHub CLI
    print("\n=== Test 6: GitHub CLI ===")
    machine.succeed("docker run --rm github-runner:nixos-latest gh --version")
    
    # Test 7: Check CodeQL
    print("\n=== Test 7: CodeQL ===")
    machine.succeed("docker run --rm github-runner:nixos-latest codeql --version")
    
    # Test 8: Check Docker client
    print("\n=== Test 8: Docker Client ===")
    machine.succeed("docker run --rm github-runner:nixos-latest docker --version")
    
    # Test 9: Check compression tools
    print("\n=== Test 9: Compression Tools ===")
    machine.succeed("docker run --rm github-runner:nixos-latest tar --version")
    machine.succeed("docker run --rm github-runner:nixos-latest gzip --version")
    machine.succeed("docker run --rm github-runner:nixos-latest xz --version")
    machine.succeed("docker run --rm github-runner:nixos-latest unzip -v")
    machine.succeed("docker run --rm github-runner:nixos-latest bzip2 --version")
    
    # Test 10: Check text processing utilities
    print("\n=== Test 10: Text Processing ===")
    machine.succeed("docker run --rm github-runner:nixos-latest jq --version")
    machine.succeed("docker run --rm github-runner:nixos-latest yq --version")
    
    # Test 11: Check OpenSSL and libraries
    print("\n=== Test 11: Libraries ===")
    machine.succeed("docker run --rm github-runner:nixos-latest which openssl")
    
    # Test 12: Test /usr/bin/env exists (needed by many scripts)
    print("\n=== Test 12: Standard Paths ===")
    machine.succeed("docker run --rm github-runner:nixos-latest test -L /usr/bin/env")
    machine.succeed("docker run --rm github-runner:nixos-latest /usr/bin/env echo 'test'")
    
    # Test 13: Test passwd and user setup
    print("\n=== Test 13: User Configuration ===")
    machine.succeed("docker run --rm github-runner:nixos-latest test -f /etc/passwd")
    machine.succeed("docker run --rm github-runner:nixos-latest test -f /etc/group")
    machine.succeed("docker run --rm github-runner:nixos-latest whoami")
    
    # Test 14: Test environment variables
    print("\n=== Test 14: Environment Variables ===")
    machine.succeed("docker run --rm github-runner:nixos-latest bash -c 'test -n \"$HOME\"'")
    machine.succeed("docker run --rm github-runner:nixos-latest bash -c 'test -n \"$SHELL\"'")
    machine.succeed("docker run --rm github-runner:nixos-latest bash -c 'test -n \"$PATH\"'")
    machine.succeed("docker run --rm github-runner:nixos-latest bash -c 'echo $GITHUB_HOST | grep github.com'")
    
    # Test 15: Test Nix configuration
    print("\n=== Test 15: Nix Configuration ===")
    machine.succeed("docker run --rm github-runner:nixos-latest test -f /etc/nix/nix.conf")
    machine.succeed("docker run --rm github-runner:nixos-latest nix eval --expr '1 + 1'")
    
    # Test 16: Test a simple Rust build
    print("\n=== Test 16: Rust Build Test ===")
    machine.succeed("""
      docker run --rm github-runner:nixos-latest bash -c '
        mkdir -p /tmp/test-project && cd /tmp/test-project &&
        cargo init --name test-app &&
        cargo build --release
      '
    """)
    
    # Test 17: Test a simple Node.js script
    print("\n=== Test 17: Node.js Test ===")
    machine.succeed("""
      docker run --rm github-runner:nixos-latest bash -c '
        node -e "console.log(\"Node.js works!\")"
      '
    """)
    
    # Test 18: Test git operations
    print("\n=== Test 18: Git Operations ===")
    machine.succeed("""
      docker run --rm github-runner:nixos-latest bash -c '
        cd /tmp &&
        git config --global user.email "test@example.com" &&
        git config --global user.name "Test User" &&
        git init test-repo &&
        cd test-repo &&
        echo "test" > README.md &&
        git add README.md &&
        git commit -m "Initial commit"
      '
    """)
    
    # Test 19: Test SSL certificates
    print("\n=== Test 19: SSL Certificates ===")
    machine.succeed("docker run --rm github-runner:nixos-latest bash -c 'test -n \"$SSL_CERT_FILE\"'")
    machine.succeed("docker run --rm github-runner:nixos-latest test -f /etc/ssl/certs/ca-bundle.crt")
    
    # Test 20: Verify runner directory structure
    print("\n=== Test 20: Runner Structure ===")
    machine.succeed("docker run --rm github-runner:nixos-latest test -d /runner")
    machine.succeed("docker run --rm github-runner:nixos-latest test -d /root")
    machine.succeed("docker run --rm github-runner:nixos-latest test -d /tmp")
    
    print("\n=== All tests passed! ===")
  '';
}
