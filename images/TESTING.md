# Testing the GitHub Runner Image

The runner image includes comprehensive automated tests using NixOS testing framework.

## Running Tests Locally

### Run all tests
```bash
nix build /etc/nixos#checks.x86_64-linux.github-runner-test
```

This will:
1. Build the runner image
2. Spin up a NixOS VM with Docker
3. Load the image into Docker
4. Run 20 comprehensive test suites

### View test results
```bash
# Test results are displayed in the build output
# Failed tests will show detailed error messages
```

## What Gets Tested

### Test Suites (20 total)

1. **Core Utilities** - bash, git, curl, wget
2. **Nix** - nix, nixpkgs-fmt
3. **Build Tools** - gcc, make, cmake, pkg-config
4. **Rust Toolchain** - rustc, cargo, rustfmt, clippy
5. **Node.js** - node v20.x, npm
6. **GitHub CLI** - gh
7. **CodeQL** - codeql for Copilot
8. **Docker Client** - docker
9. **Compression Tools** - tar, gzip, xz, unzip, bzip2
10. **Text Processing** - jq, yq
11. **Libraries** - OpenSSL
12. **Standard Paths** - /usr/bin/env
13. **User Configuration** - /etc/passwd, /etc/group
14. **Environment Variables** - HOME, SHELL, PATH, GITHUB_HOST
15. **Nix Configuration** - /etc/nix/nix.conf, flakes support
16. **Rust Build** - Full cargo build test
17. **Node.js Execution** - JavaScript execution test
18. **Git Operations** - Clone, commit, config
19. **SSL Certificates** - CA bundle
20. **Runner Structure** - Directory layout

## CI/CD Integration

Tests are automatically run in CI:

### On Pull Requests
- `.github/workflows/release-pr.yml` runs tests before merge

### On Release
- `.github/workflows/release.yml` runs tests before publishing

## Test Implementation

Tests are defined in `/etc/nixos/images/github-runner/test.nix` using the NixOS testing framework.

### Adding New Tests

To add a new test, edit `test.nix`:

```nix
# Add to testScript section
print("\n=== Test N: Description ===")
machine.succeed("docker run --rm github-runner:nixos-latest your-test-command")
```

### Test Philosophy

- **Fast**: Tests should complete in < 5 minutes
- **Comprehensive**: Cover all major functionality
- **Realistic**: Test actual use cases (builds, git ops, etc.)
- **Isolated**: Each test is independent

## Debugging Failed Tests

If a test fails:

1. Check the build log for the specific failing command
2. Build the image manually: `nix build /etc/nixos#github-runner-image`
3. Load it locally: `docker load < result`
4. Run the failing command interactively:
   ```bash
   docker run --rm -it github-runner:nixos-latest bash
   ```

## Local Development Workflow

```bash
# 1. Make changes to default.nix
vim /etc/nixos/images/github-runner/default.nix

# 2. Rebuild image
nix build /etc/nixos#github-runner-image

# 3. Run tests
nix build /etc/nixos#checks.x86_64-linux.github-runner-test

# 4. If tests pass, commit and push
git add images/github-runner/
git commit -m "feat: improve runner image"
```

## Performance

Test execution time breakdown:
- VM startup: ~30s
- Image load: ~10s  
- Test execution: ~2-3 min
- **Total**: ~3-4 minutes

## Unfree Packages

The image includes CodeQL which has an unfree license. This is explicitly allowed only for CodeQL:

```nix
config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
  "codeql"
];
```

No `--impure` flag is needed for builds.
