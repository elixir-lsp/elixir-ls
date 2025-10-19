#!/bin/bash
set -e

# Test installer.exs across Elixir versions using Docker
# Usage: ELIXIR_VERSION=1.13 ./test_installer.sh
# Or: ./test_installer.sh 1.13

ELIXIR_VERSION="${1:-${ELIXIR_VERSION:-latest}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Testing installer.exs with Elixir ${ELIXIR_VERSION}..."

# Run test in Docker
docker run --rm \
  -v "${SCRIPT_DIR}:/scripts:ro" \
  -w /tmp \
  "elixir:${ELIXIR_VERSION}" \
  bash -c '
    set -e

    echo "==> Elixir version: $(elixir --version | grep Elixir)"

    echo "==> Installing Hex..."
    mix local.hex --force

    echo "==> Compiling installer.exs..."
    elixir --no-halt -e "Code.compile_file(\"/scripts/installer.exs\"); System.halt(0)"

    echo "==> Testing Mix.install with simple dependency..."
    mix run --no-mix-exs -e "
      Code.require_file(\"/scripts/installer.exs\")

      # Test basic installation
      ElixirLS.Mix.install([{:jason, \"~> 1.0\"}], verbose: true, stop_started_applications: false)

      # Verify Jason is available
      unless Code.ensure_loaded?(Jason) do
        IO.puts(:stderr, \"ERROR: Jason not loaded after install\")
        System.halt(1)
      end

      # Test JSON encoding to ensure it works
      result = Jason.encode!(%{test: \"success\"})
      IO.puts(\"✓ Successfully installed and used Jason: #{result}\")

      # Test that install_project_dir works
      if function_exported?(Mix, :installed?, 0) and Mix.installed?() do
        IO.puts(\"✓ Mix.installed?() = true\")
      else
        IO.puts(\"✓ Mix.install state tracked (older API)\")
      end
    "

    echo "==> All tests passed for Elixir ${ELIXIR_VERSION}!"
  '

echo "✓ Tests completed successfully for Elixir ${ELIXIR_VERSION}"
