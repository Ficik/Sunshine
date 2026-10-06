Sunshine Desktop for Ubuntu 22.04 and 24.04, amd64.

- Paired-client, bidirectional UTF-8 clipboard sharing with Ficik/moonlight-web-stream.
- X11 capture and clipboard enabled in the packaged user service.
- Software and VAAPI encoding; no tray, CUDA, Wayland or KMS capture in these builds.
- Each package is installation-tested against stock repositories for its Ubuntu version.

Download the package matching your Ubuntu release, verify SHA256SUMS, and install
with `sudo apt install ./sunshine_*.deb`. See the attached INSTALL.md for startup,
pairing, configuration preservation, and upgrade instructions.

For first startup, run `systemctl --user daemon-reload` followed by
`systemctl --user enable --now app-dev.lizardbyte.app.Sunshine.service` as the
desktop user. This release corrects the initial service-enablement instructions.

Source is the immutable release tag. SOURCE_COMMIT and SUBMODULES.txt record the
exact source revisions. These are community desktop builds maintained by Ficik.
