#!/usr/bin/env bash
# Run as root inside a clean target Ubuntu container with /packages mounted.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends /packages/*.deb
test "$(dpkg-query -W -f='${Architecture}' sunshine)" = amd64
command -v xclip
test -f /usr/lib/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/desktop.conf
grep -Fx 'ExecStart=/usr/bin/sunshine capture=x11' \
  /usr/lib/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/desktop.conf
grep -Fx 'Environment=SUNSHINE_CLIPBOARD=1' \
  /usr/lib/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/desktop.conf
# Container smoke tests have no GPU. Strip upstream KMS file capabilities so an
# unprivileged container can execute the binary; installed hosts retain theirs.
setcap -r /usr/bin/sunshine || true
sunshine --version
if ldd /usr/bin/sunshine | grep -q 'not found'; then exit 1; fi
echo 'PASS: package installs and runs using only stock Ubuntu repositories'
