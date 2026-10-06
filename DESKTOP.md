# Sunshine Desktop

This fork adds authenticated, bidirectional text clipboard support for
[Ficik/moonlight-web-stream](https://github.com/Ficik/moonlight-web-stream/tree/desktop).
The maintained branch is `desktop`. Upstream base:
`11eb4fb4d04953ba9e821af29b50914b0577b994`.

## Install on Ubuntu 22.04 or 24.04 (amd64)

Download the matching `.deb` and SHA256SUMS from this fork's GitHub Releases.
Check the downloaded package's checksum against SHA256SUMS, then:

```sh
sudo apt install ./sunshine_*.deb
systemctl --user daemon-reload
systemctl --user enable --now sunshine.service
```

Run these user-service commands as the desktop user, in an X11 graphical session.
Use the existing Sunshine web interface on HTTPS port 47990 to set credentials
and pair each client. No credentials or paired devices are included in packages.
Firewall policy remains an operator decision; the package does not expose ports.

The packaged service sets `SUNSHINE_CLIPBOARD=1` and passes `capture=x11` as a
configuration override. Existing files in `~/.config/sunshine` are preserved,
including credentials, pairing keys, apps and other settings. A direct manual
launch must set that environment variable and `capture=x11` itself.
The package depends on xclip, used without a shell to handle X11 selections.
Clipboard access is available only to paired clients over the existing TLS API.
Text is limited to 1 MiB; image/file clipboard formats are not implemented.

These packages enable X11 capture, VAAPI and software encoding. Tray, CUDA,
Wayland, Vulkan and KMS capture are disabled. Install GPU drivers appropriate
for the host separately. The service uses the normal desktop user's display
environment; it does not assume `DISPLAY=:0` or a hardcoded home directory.

## Upgrade and rollback

Install a newer matching package with the same `apt install ./...deb` command,
then `systemctl --user daemon-reload` and `systemctl --user restart sunshine`.
Package name stays `sunshine`, so dpkg upgrades the installation in place.
For rollback, install a retained older `.deb` and restart the service. Back up
`~/.config/sunshine` before upgrading across upstream versions that change state.
GitHub release assets are not an APT repository: `apt upgrade` alone will not
download these builds.

## Build and release

The Desktop Ubuntu packages workflow builds separately on Ubuntu 22.04/24.04.
Every push to `desktop` or `upgrade/**` publishes test packages as Actions
artifacts. Release tags have the form `desktop-v2026.1006.1` and must match
`packaging/desktop/VERSION`. Only after both platform jobs pass does CI publish
a GitHub Release with `.deb` files, checksums, and source/submodule revisions.
The workflow uses the repository's GITHUB_TOKEN; no personal release token is
required. Enable Actions in your GitHub fork if GitHub has disabled fork workflows.

Build inputs are committed lockfiles, pinned submodules, Node 26.4.0 and CMake
3.31.8. GCC 14 comes from the Ubuntu toolchain build PPA; its C++ runtime is
linked statically so installed booths do not need that PPA. CI installs and runs
the finished package in a fresh container with stock Ubuntu repositories.
System build dependencies follow Ubuntu package updates, so builds are traceable
but not claimed to be bit-for-bit reproducible.

Run `bash scripts/build-desktop-deb.sh` only in a disposable target Ubuntu
environment with Node installed. It installs build dependencies. X11 clipboard
tests use Xvfb, including Unicode, empty/1 MiB transfers, invalid input and child
reaper contention. Actual GPU capture and browser integration need a desktop
smoke test before rolling a new upstream version across the fleet.

## Updating upstream

Keep `origin` pointed to Ficik/Sunshine and `upstream` to LizardByte/Sunshine.
Keep clipboard code and packaging/CI changes in separate commits.

1. Fetch upstream tags and choose a stable release or explicit commit.
2. Create `upgrade/<version>` from `desktop`, then rebase the desktop patch series
   using `git rebase --onto <new-upstream> <recorded-old-upstream>`.
3. Resolve conflicts; update the upstream base above and package VERSION.
4. Push the upgrade branch, review CI, and smoke-test the three-repository stack.
5. Update `desktop` to the tested result (use `--force-with-lease` if rebased),
   then create and push a new matching `desktop-v...` tag.

Never rewrite a released tag or replace its assets. Releases identify exact
source snapshots even when the development branch is later rebased.
