#!/usr/bin/env bash
# VA display allocation and core operations must use the same system runtime.
set -euo pipefail
binary="${1:?Usage: test-desktop-vaapi-linkage.sh /path/to/sunshine}"
symbols=$(readelf --dyn-syms --wide "$binary")
for symbol in vaGetDisplayDRM vaInitialize vaTerminate; do
  if ! awk -v symbol="$symbol" '
    $7 == "UND" && ($8 == symbol || index($8, symbol "@") == 1) { found = 1 }
    END { exit !found }
  ' <<< "$symbols"; then
    echo "FAIL: $symbol must be imported from the system VA-API libraries" >&2
    exit 1
  fi
done
dependencies=$(readelf --dynamic --wide "$binary")
for library in libva.so.2 libva-drm.so.2; do
  if ! grep -Fq "[$library]" <<< "$dependencies"; then
    echo "FAIL: missing shared dependency $library" >&2
    exit 1
  fi
done
echo 'PASS: VA-API uses the shared system runtime'
