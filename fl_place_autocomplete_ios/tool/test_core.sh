#!/usr/bin/env bash
# Runs the pure-Swift FlPlaceAutocompleteCore unit tests on macOS.
# FL_PLACE_AUTOCOMPLETE_CORE_ONLY=1 drops the Flutter/Places dependencies from Package.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
FL_PLACE_AUTOCOMPLETE_CORE_ONLY=1 swift test --package-path ios/fl_place_autocomplete_ios "$@"
