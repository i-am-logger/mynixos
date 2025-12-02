{ pkgs }:

let
  image = import ./. { inherit pkgs; };

  # Extract and verify the image contents without loading into Docker
  verifyImage = pkgs.runCommand "github-runner-image-check"
    {
      buildInputs = [ pkgs.jq pkgs.skopeo ];
    }
    ''
      echo "Checking GitHub runner image structure..."
      
      # Verify the image derivation exists and is valid
      if [ ! -f "${image}" ]; then
        echo "ERROR: Image file not found at ${image}"
        exit 1
      fi
      
      echo "✓ Image built successfully: ${image}"
      
      # Check image size (should be reasonable)
      size=$(stat -c%s "${image}" || stat -f%z "${image}")
      size_mb=$((size / 1024 / 1024))
      echo "✓ Image size: ''${size_mb}MB"
      
      if [ $size_mb -lt 100 ]; then
        echo "ERROR: Image seems too small (''${size_mb}MB)"
        exit 1
      fi
      
      if [ $size_mb -gt 5000 ]; then
        echo "WARNING: Image is quite large (''${size_mb}MB)"
      fi
      
      # Verify it's a valid tar archive
      if ! tar -tzf "${image}" >/dev/null 2>&1; then
        echo "ERROR: Image is not a valid tar archive"
        exit 1
      fi
      
      echo "✓ Image is a valid tar archive"
      
      # Extract and check manifest
      tar -xzOf "${image}" manifest.json > manifest.json 2>/dev/null || true
      
      if [ -f manifest.json ]; then
        echo "✓ Image manifest found"
        
        # Check that the image has the expected tag
        if ! grep -q "github-runner" manifest.json; then
          echo "ERROR: Image doesn't contain 'github-runner' in manifest"
          exit 1
        fi
        
        echo "✓ Image has correct name in manifest"
      fi
      
      # Success - create marker file
      echo "All checks passed!" > $out
      echo "✓ GitHub runner image checks completed successfully"
    '';
in
verifyImage
