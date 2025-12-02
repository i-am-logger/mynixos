# Workflow Cleanup Guide

Now that the custom NixOS runner image includes commonly-used tools, you can clean up your workflows by removing redundant installation steps.

## Packages Included in Base Image

The runner image now includes:

### Development Tools
- **Rust**: `rustc`, `cargo`, `rustfmt`, `clippy`
- **Node.js**: `nodejs_20` (v20.x)
- **Build tools**: `gcc`, `gnumake`, `cmake`, `pkg-config`, `autoconf`, `automake`, `libtool`

### CLI Tools
- **GitHub CLI**: `gh` (pre-installed, no more apt-get install needed!)
- **CodeQL**: Pre-installed for GitHub Copilot coding agent
- **Nix**: Full Nix with flakes + `nixpkgs-fmt`
- **Docker**: `docker` client

### Utilities
- **Archives**: `tar`, `gzip`, `xz`, `unzip`, `zip`, `bzip2`
- **Text processing**: `jq`, `yq`, `grep`, `sed`, `awk`
- **Network**: `curl`, `wget`, `openssh`
- **VCS**: `git`
- **System**: `which`, `file`, `procps`

## Workflow Steps You Can Remove

### ❌ Remove: GitHub CLI Installation

**Before:**
```yaml
- name: Install gh CLI
  run: |
    type -p curl >/dev/null || (sudo apt-get update && sudo apt-get install curl -y)
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update
    sudo apt-get install gh -y
```

**After:**
```yaml
# No installation needed - gh is already in the image!
- name: Do something with gh
  run: gh --version
```

### ❌ Remove: Build Essential Installation (for pds runners)

**Before:**
```yaml
- name: Install system dependencies
  if: matrix.os == 'pds'
  run: |
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends build-essential
```

**After:**
```yaml
# No installation needed - build tools are already in the image!
```

### ❌ Remove: CodeQL Installation (from copilot-setup-steps)

**Before:**
```yaml
- name: Install required tools
  run: |
    set -e
    echo "Installing required tools..."
    
    # Install CodeQL
    echo "Installing CodeQL for Copilot coding agent..."
    CODEQL_VERSION="2.15.5"
    CODEQL_HOME="/opt/hostedtoolcache/CodeQL/${CODEQL_VERSION}/x64"
    
    sudo mkdir -p "${CODEQL_HOME}"
    wget -q "https://github.com/github/codeql-action/releases/download/codeql-bundle-v${CODEQL_VERSION}/codeql-bundle-linux64.tar.gz"
    sudo tar -xzf codeql-bundle-linux64.tar.gz -C "${CODEQL_HOME}" --strip-components=1
    rm codeql-bundle-linux64.tar.gz
    sudo chmod -R 755 "${CODEQL_HOME}"
    echo "${CODEQL_HOME}/codeql" >> $GITHUB_PATH
```

**After:**
```yaml
# No installation needed - CodeQL is already in the image!
# Just verify it's available
- name: Verify CodeQL
  run: codeql --version
```

### ❌ Remove: xz-utils Installation (from setup-nix action)

**Before (in `.github/actions/setup-nix/action.yml`):**
```yaml
- name: Install dependencies
  shell: bash
  run: |
    if ! command -v xz &> /dev/null; then
      echo "Installing xz-utils..."
      sudo apt-get update -qq
      sudo apt-get install -y -qq xz-utils
    fi
```

**After:**
```yaml
# No installation needed - xz is already in the image!
# This entire step can be removed
```

### ✅ Simplify: Rust Setup (for pds workflows)

**Before:**
```yaml
- name: Setup Rust
  uses: actions-rust-lang/setup-rust-toolchain@v1
  with:
    toolchain: stable
    target: ${{ matrix.target }}
```

**After:**
```yaml
# Rust is pre-installed, but you may still need target setup for cross-compilation
- name: Add Rust target
  if: matrix.target != 'x86_64-unknown-linux-gnu'
  run: rustup target add ${{ matrix.target }}
```

For native Linux builds on the `pds` runner, you can skip Rust setup entirely!

### ✅ Keep: Node.js Setup Action (for version management)

**Keep this:**
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: "20"
```

While Node.js 20 is in the image, the action provides npm caching and version pinning which is still useful.

## Files to Update

### 1. `/etc/nixos/.github/actions/setup-nix/action.yml`

Remove the xz-utils installation step entirely:

```yaml
name: 'Setup Nix'
description: 'Install Nix with caching - reusable setup for all workflows'
runs:
  using: composite
  steps:
    - name: Install Nix
      uses: DeterminateSystems/nix-installer-action@main
      
    - name: Setup Nix cache
      uses: DeterminateSystems/magic-nix-cache-action@main
      
    - name: Verify Nix installation
      shell: bash
      run: |
        echo "✓ Nix version: $(nix --version)"
        echo "✓ Nix store: $NIX_STORE_DIR"
```

### 2. `~/Code/github/logger/pds/.github/workflows/pr.yml`

Remove ALL `Install gh CLI` steps (lines 20-27, 107-114, 170-177, 192-199)

Remove the `Install system dependencies` step (lines 54-58)

### 3. `~/Code/github/logger/pds/.github/workflows/release.yml`

Remove the `Install gh CLI` step (lines 85-92)

Remove the `Install system dependencies` step (lines 31-35)

### 4. `~/Code/github/logger/pds/.github/workflows/release-pr.yml`

Remove the `Install system dependencies` step (lines 33-37)

### 5. `~/Code/github/logger/pds/.github/workflows/copilot-setup-steps.yml`

Simplify the system dependencies step to only install what's truly needed (if anything beyond the base image).

## Testing

After cleanup, test your workflows to ensure they still work:

1. Create a test branch
2. Push changes
3. Verify all workflow steps complete successfully
4. Check that tools are available without installation

## Benefits

- **Faster workflows**: No time wasted on apt-get updates and package installations
- **Cleaner code**: Less boilerplate in workflow files
- **More reliable**: No network issues during package downloads
- **Reproducible**: Same environment across all runners
