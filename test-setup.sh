#!/bin/bash

# Test script to verify the StackGuardian Template Sync setup

echo "=== StackGuardian Template Sync Setup Test ==="

# Check if required files exist
echo "Checking required files..."

REQUIRED_FILES=(
  ".github/workflows/sync.yml"
  ".github/actions/sync/action.yml"
  "push.sh"
  "pull.sh"
  "README.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    echo "  ✓ $file exists"
  else
    echo "  ✗ $file is missing"
  fi
done

# Check if .sg directory exists
echo
echo "Checking .sg directory..."
if [[ -d ".sg" ]]; then
  echo "  ✓ .sg directory exists"
  echo "  Contents:"
  ls -la .sg/
else
  echo "  ✗ .sg directory is missing"
fi

# Check if example files exist
echo
echo "Checking example files..."
if [[ -f ".github/workflows/stackguardian-template-sync-example.yml" ]]; then
  echo "  ✓ Example workflow file exists"
else
  echo "  ✗ Example workflow file is missing"
fi

if [[ -f "example-config.md" ]]; then
  echo "  ✓ Example configuration file exists"
else
  echo "  ✗ Example configuration file is missing"
fi

echo
echo "=== Setup Test Complete ==="
echo
echo "Next steps:"
echo "1. Review the README.md file for detailed instructions"
echo "2. Configure the required GitHub secrets"
echo "3. Customize the workflow file as needed"
echo "4. Test the workflow manually through GitHub Actions"