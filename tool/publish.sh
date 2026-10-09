#!/usr/bin/env bash
# Publish all packages in dependency order. Pass --dry-run to only validate.
set -euo pipefail
cd "$(dirname "$0")/.."
dry="${1:-}"
pub() { (cd "$1" && dart pub publish $dry); }
wait_live() { [ -n "$dry" ] || read -r -p "Wait until $1 is live on pub.dev, then press Enter: "; }

pub fl_place_autocomplete_platform_interface
wait_live platform_interface
for p in android ios web; do pub "fl_place_autocomplete_$p"; done
wait_live "android, ios and web"
pub fl_place_autocomplete
