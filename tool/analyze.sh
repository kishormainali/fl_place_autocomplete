#!/usr/bin/env bash
# Analyze every package in the workspace.
set -euo pipefail
cd "$(dirname "$0")/.."
for d in fl_place_autocomplete*/; do
  (cd "$d" && flutter analyze)
done
