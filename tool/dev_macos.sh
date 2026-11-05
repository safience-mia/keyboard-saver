#!/usr/bin/env bash
set -euo pipefail

# Launch through Launch Services so TCC checks this app instead of the editor
# that owns the terminal. Attach afterwards to keep Flutter hot reload.
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_bundle="$repo_dir/build/macos/Build/Products/Debug/Keyboard Saver Debug.app"
build_app=true

case "${1:-}" in
  --no-build) build_app=false ;;
  -h|--help)
    printf '%s\n' 'Usage: bash tool/dev_macos.sh [--no-build]' \
      'Build and open the macOS Debug app, then attach Flutter for hot reload.' \
      'Use --no-build to reuse the existing Debug app without changing its signature.'
    exit 0
    ;;
  '') ;;
  *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
esac
if [[ "$#" -gt 1 || "$(uname -s)" != Darwin ]]; then
  printf '%s\n' 'Run this script on macOS with at most one option.' >&2
  exit 1
fi

if /usr/bin/pgrep -x 'Keyboard Saver Debug' >/dev/null; then
  printf '%s\n' 'Quit Keyboard Saver Debug before running this script.' >&2
  exit 1
fi

if command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
elif [[ -x "$HOME/development/flutter/bin/flutter" ]]; then
  flutter_bin="$HOME/development/flutter/bin/flutter"
else
  printf '%s\n' 'Flutter SDK not found. Add its bin directory to PATH.' >&2
  exit 1
fi

cd "$repo_dir"
if [[ "$build_app" == true ]]; then
  "$flutter_bin" build macos --debug
fi
if [[ ! -x "$app_bundle/Contents/MacOS/Keyboard Saver Debug" ]]; then
  printf '%s\n' 'Debug app not found. Run without --no-build to build it first.' >&2
  exit 1
fi

log_dir="$(mktemp -d "${TMPDIR:-/tmp}/keyboard-saver-dev.XXXXXX")"
log_file="$log_dir/app.log"
error_file="$log_dir/app-error.log"
touch "$log_file" "$error_file"
/usr/bin/open -n -a "$app_bundle" --stdout "$log_file" --stderr "$error_file"

service_url=''
for ((attempt = 0; attempt < 60; attempt++)); do
  service_url="$(sed -nE 's/.*Dart VM service is listening on (http:\/\/[^[:space:]]+).*/\1/p' "$log_file" | head -n 1)"
  if [[ -n "$service_url" ]]; then break; fi
  sleep 0.5
done
if [[ -z "$service_url" ]]; then
  printf 'Dart VM Service was not found. App logs: %s\n' "$log_dir" >&2
  exit 1
fi

printf 'App log: %s\n' "$log_file"
printf '%s\n' 'Connecting Flutter. Use r for hot reload and R for hot restart.'
"$flutter_bin" attach -d macos --debug-url "$service_url"
