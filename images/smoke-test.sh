#!/usr/bin/env bash
set -euo pipefail

echo "=== GitHub Runner Image Smoke Test ==="
echo ""

IMAGE="github-runner:nixos-latest"

# Check if image exists
if ! docker images | grep -q "github-runner"; then
    echo "Error: Image $IMAGE not found. Please build and load it first:"
    echo "  nix build /etc/nixos#github-runner-image"
    echo "  docker load < result"
    exit 1
fi

echo "✓ Image found: $IMAGE"
echo ""

# Test 1: Basic tools
echo "Test 1: Core Utilities"
docker run --rm "$IMAGE" bash --version > /dev/null && echo "  ✓ bash"
docker run --rm "$IMAGE" git --version > /dev/null && echo "  ✓ git"
docker run --rm "$IMAGE" curl --version > /dev/null && echo "  ✓ curl"
docker run --rm "$IMAGE" wget --version > /dev/null && echo "  ✓ wget"

# Test 2: Build tools
echo ""
echo "Test 2: Build Tools"
docker run --rm "$IMAGE" gcc --version > /dev/null && echo "  ✓ gcc"
docker run --rm "$IMAGE" make --version > /dev/null && echo "  ✓ make"
docker run --rm "$IMAGE" cmake --version > /dev/null && echo "  ✓ cmake"

# Test 3: Rust
echo ""
echo "Test 3: Rust Toolchain"
docker run --rm "$IMAGE" rustc --version > /dev/null && echo "  ✓ rustc"
docker run --rm "$IMAGE" cargo --version > /dev/null && echo "  ✓ cargo"

# Test 4: Node.js
echo ""
echo "Test 4: Node.js"
NODE_VERSION=$(docker run --rm "$IMAGE" node --version)
echo "  ✓ node $NODE_VERSION"
[[ "$NODE_VERSION" == v20* ]] || (echo "  ✗ Expected Node.js v20.x" && exit 1)

# Test 5: GitHub tools
echo ""
echo "Test 5: GitHub Tools"
docker run --rm "$IMAGE" gh --version > /dev/null && echo "  ✓ gh CLI"
docker run --rm "$IMAGE" codeql --version > /dev/null && echo "  ✓ CodeQL"

# Test 6: Nix
echo ""
echo "Test 6: Nix"
docker run --rm "$IMAGE" nix --version > /dev/null && echo "  ✓ nix"
docker run --rm "$IMAGE" nixpkgs-fmt --version > /dev/null && echo "  ✓ nixpkgs-fmt"

# Test 7: Standard paths
echo ""
echo "Test 7: Standard Paths"
docker run --rm "$IMAGE" test -L /usr/bin/env && echo "  ✓ /usr/bin/env exists"
docker run --rm "$IMAGE" /usr/bin/env bash -c "echo ok" > /dev/null && echo "  ✓ /usr/bin/env works"

# Test 8: Rust build
echo ""
echo "Test 8: Rust Build"
docker run --rm "$IMAGE" bash -c "cd /tmp && cargo init --quiet testproject && cd testproject && cargo build --quiet 2>&1" > /dev/null
echo "  ✓ Cargo project builds successfully"

# Test 9: Environment
echo ""
echo "Test 9: Environment Variables"
docker run --rm "$IMAGE" bash -c 'test -n "$HOME"' && echo "  ✓ HOME is set"
docker run --rm "$IMAGE" bash -c 'test -n "$SHELL"' && echo "  ✓ SHELL is set"
docker run --rm "$IMAGE" bash -c 'test -n "$PATH"' && echo "  ✓ PATH is set"

echo ""
echo "=== All smoke tests passed! ==="
echo ""
echo "To run full test suite:"
echo "  nix build /etc/nixos#checks.x86_64-linux.github-runner-test"
