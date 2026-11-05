#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/keyboard-saver-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

if [[ "$(uname -s)" == "Darwin" ]]; then
  swiftc -module-cache-path "$test_dir/module-cache" \
    "$repo_dir/packages/keyboard_guard/macos/keyboard_guard/Sources/keyboard_guard/SystemKeyEvent.swift" \
    "$repo_dir/packages/keyboard_guard/test/native/system_key_event_test.swift" \
    -o "$test_dir/system_keys_swift"
  "$test_dir/system_keys_swift"
fi
