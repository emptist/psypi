#!/bin/bash
# Build psypi_core and generate extension.js
# Usage: ./build.sh

set -e

echo "=== Cleaning build cache ==="
rm -rf build/

echo "=== Building Gleam ==="
gleam build

echo "=== Generating extension.js ==="
gleam run -m psypi_cli/extension_generator

echo "=== Done ==="
echo "extension.js generated at src/agent/extension/extension.js"
