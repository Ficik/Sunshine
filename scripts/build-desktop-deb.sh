#!/usr/bin/env bash
# Build on the target Ubuntu release; run in a disposable container/CI runner.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" =~ ^(22\.04|24\.04)$ ]]
[[ "$(dpkg --print-architecture)" == amd64 ]]
sudo_cmd=()
if (( EUID != 0 )); then sudo_cmd=(sudo); fi
export DEBIAN_FRONTEND=noninteractive
"${sudo_cmd[@]}" apt-get update
"${sudo_cmd[@]}" apt-get install -y --no-install-recommends software-properties-common ca-certificates gnupg
"${sudo_cmd[@]}" add-apt-repository -y ppa:ubuntu-toolchain-r/test
"${sudo_cmd[@]}" apt-get update
"${sudo_cmd[@]}" apt-get install -y --no-install-recommends \
  gcc-14 g++-14 ninja-build git curl pkg-config python3-venv python3-jinja2 \
  libssl-dev libcurl4-openssl-dev libcap-dev libdrm-dev libevdev-dev \
  libgbm-dev libminiupnpc-dev libnuma-dev libopus-dev libpulse-dev libva-dev \
  libsystemd-dev libudev-dev libx11-dev libxcb-shm0-dev libxcb-xfixes0-dev \
  libxfixes-dev libxrandr-dev libxtst-dev libicu-dev libgl-dev libwayland-dev \
  xclip xvfb xauth dpkg-dev file

tools_dir="${DESKTOP_TOOLS_DIR:-$PWD/cmake-build-desktop-tools}"
python3 -m venv "$tools_dir"
"$tools_dir/bin/pip" install --disable-pip-version-check cmake==3.31.10
export PATH="$tools_dir/bin:$PATH"
export CC=gcc-14 CXX=g++-14
export BRANCH=desktop
export BUILD_VERSION="${DESKTOP_VERSION:-$(cat packaging/desktop/VERSION)+desktop}"
export COMMIT="$(git rev-parse HEAD)"
export DEBIAN_PACKAGE_RELEASE="0ubuntu${VERSION_ID}"
build_dir="${DESKTOP_BUILD_DIR:-cmake-build-desktop}"
cmake -S . -B "$build_dir" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_EXE_LINKER_FLAGS='-static-libstdc++ -static-libgcc' \
  -DBUILD_DOCS=OFF -DBUILD_TESTS=OFF -DBUILD_WERROR=OFF \
  -DBOOST_USE_STATIC=ON -DSUNSHINE_ENABLE_TRAY=OFF \
  -DSUNSHINE_ENABLE_X11=ON -DSUNSHINE_ENABLE_VAAPI=ON \
  -DSUNSHINE_ENABLE_CUDA=OFF -DSUNSHINE_ENABLE_DRM=OFF \
  -DSUNSHINE_ENABLE_WAYLAND=OFF -DSUNSHINE_ENABLE_VULKAN=OFF \
  -DSUNSHINE_ENABLE_KWIN=OFF -DSUNSHINE_ENABLE_PORTAL=OFF \
  -DGLAD_SKIP_PIP_INSTALL=ON -DPython_EXECUTABLE=/usr/bin/python3 \
  -DSUNSHINE_DESKTOP_PACKAGE=ON \
  -DSUNSHINE_PUBLISHER_NAME=Ficik \
  -DSUNSHINE_PUBLISHER_WEBSITE=https://github.com/Ficik/Sunshine \
  -DSUNSHINE_PUBLISHER_ISSUE_URL=https://github.com/Ficik/Sunshine/issues
cmake --build "$build_dir" --parallel "${JOBS:-2}"

# Exercise the actual clipboard helper in a private X server, including 1 MiB
# INCR transfers and contention with the process reaper. No physical GPU needed.
gtest=third-party/lizardbyte-common/third-party/googletest/googletest
g++-14 -std=c++23 -DSUNSHINE_BUILD_X11 -I. -I"$gtest/include" -I"$gtest" \
  tests/unit/test_clipboard.cpp "$gtest/src/gtest-all.cc" "$gtest/src/gtest_main.cc" \
  -pthread -o "$build_dir/test_desktop_clipboard"
xvfb-run -a env SUNSHINE_CLIPBOARD_TEST=1 "$build_dir/test_desktop_clipboard"
cpack --config "$build_dir/CPackConfig.cmake" -G DEB
mkdir -p artifacts
for package in "$build_dir"/cpack_artifacts/*.deb; do
  cp "$package" artifacts/
done
git rev-parse HEAD > artifacts/SOURCE_COMMIT
git submodule status --recursive > artifacts/SUBMODULES.txt
printf '%s\n' "$BUILD_VERSION" > artifacts/VERSION
(cd artifacts && sha256sum ./*.deb > SHA256SUMS)
