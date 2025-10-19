#!/bin/bash
set -e

# Test installer.exs across all supported Elixir versions
# Usage: ./test_installer_all.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Elixir versions to test (use available Docker tags)
VERSIONS=(
  "1.13"
  "1.14"
  "1.15"
  "1.16"
  "1.17"
  "1.18"
  "1.19"
  # "latest"  # Currently 1.17.x or 1.18.x
)

FAILED_VERSIONS=()
PASSED_VERSIONS=()

echo "========================================"
echo "Testing installer.exs across all Elixir versions"
echo "========================================"
echo ""

for VERSION in "${VERSIONS[@]}"; do
  echo ""
  echo "========================================"
  echo "Testing Elixir ${VERSION}"
  echo "========================================"

  if "${SCRIPT_DIR}/test_installer.sh" "${VERSION}"; then
    PASSED_VERSIONS+=("${VERSION}")
    echo "✓ Elixir ${VERSION} - PASSED"
  else
    FAILED_VERSIONS+=("${VERSION}")
    echo "✗ Elixir ${VERSION} - FAILED"
  fi
done

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed: ${#PASSED_VERSIONS[@]}"
for VERSION in "${PASSED_VERSIONS[@]}"; do
  echo "  ✓ ${VERSION}"
done

echo ""
echo "Failed: ${#FAILED_VERSIONS[@]}"
for VERSION in "${FAILED_VERSIONS[@]}"; do
  echo "  ✗ ${VERSION}"
done

if [ ${#FAILED_VERSIONS[@]} -gt 0 ]; then
  echo ""
  echo "Some tests failed!"
  exit 1
else
  echo ""
  echo "All tests passed!"
  exit 0
fi
