#!/usr/bin/env bash
# Regenerate Pigeon code (Dart + Kotlin + Swift).
set -euo pipefail
cd "$(dirname "$0")/../fl_place_autocomplete_platform_interface"
dart run pigeon --input pigeons/messages.dart
