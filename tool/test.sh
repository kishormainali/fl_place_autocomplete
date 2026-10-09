#!/usr/bin/env bash
# VM tests in every package that has a test dir.
set -euo pipefail
cd "$(dirname "$0")/.."
for d in fl_place_autocomplete*/; do
  [ -d "$d/test" ] && (cd "$d" && flutter test)
done
