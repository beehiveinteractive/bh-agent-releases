# bh-agent-releases

Public distribution point for prebuilt [Beehive Device Agent](https://beehiveinteractive.net) binaries.

The agent's source lives in a private repository. This repo carries only the
built, signed release artifacts so devices can install without a GitHub
access token.

## Latest release

**v1.7.0**

| Platform | Archive | Signature | Checksum |
|---|---|---|---|
| Linux x86_64 | [bh-agent-linux-x86_64.tar.gz](releases/v1.7.0/bh-agent-linux-x86_64.tar.gz) | [.sig](releases/v1.7.0/bh-agent-linux-x86_64.tar.gz.sig) | [.sha256](releases/v1.7.0/bh-agent-linux-x86_64.tar.gz.sha256) |
| macOS Apple Silicon | [bh-agent-macos-arm64.tar.gz](releases/v1.7.0/bh-agent-macos-arm64.tar.gz) | [.sig](releases/v1.7.0/bh-agent-macos-arm64.tar.gz.sig) | [.sha256](releases/v1.7.0/bh-agent-macos-arm64.tar.gz.sha256) |
| macOS Intel | [bh-agent-macos-x86_64.tar.gz](releases/v1.7.0/bh-agent-macos-x86_64.tar.gz) | [.sig](releases/v1.7.0/bh-agent-macos-x86_64.tar.gz.sig) | [.sha256](releases/v1.7.0/bh-agent-macos-x86_64.tar.gz.sha256) |

### Graphical installers

For machines you configure by hand rather than by script. All three ask for the
device token, the API URL and the reporting settings through a real form, so
nothing has to be composed on a command line.

| Platform | Package | Signature | Checksum |
|---|---|---|---|
| Ubuntu | [bh-agent_1.7.0_amd64.deb](releases/v1.7.0/bh-agent_1.7.0_amd64.deb) | [.sig](releases/v1.7.0/bh-agent_1.7.0_amd64.deb.sig) | [.sha256](releases/v1.7.0/bh-agent_1.7.0_amd64.deb.sha256) |
| macOS (universal) | [bh-agent-1.7.0-macos.pkg](releases/v1.7.0/bh-agent-1.7.0-macos.pkg) | [.sig](releases/v1.7.0/bh-agent-1.7.0-macos.pkg.sig) | [.sha256](releases/v1.7.0/bh-agent-1.7.0-macos.pkg.sha256) |
| Windows x86_64 | [bh-agent-windows-x86_64-setup.exe](releases/v1.7.0/bh-agent-windows-x86_64-setup.exe) | [.sig](releases/v1.7.0/bh-agent-windows-x86_64-setup.exe.sig) | [.sha256](releases/v1.7.0/bh-agent-windows-x86_64-setup.exe.sha256) |

```bash
sudo apt install ./bh-agent_1.7.0_amd64.deb      # Ubuntu
open bh-agent-1.7.0-macos.pkg                    # macOS, or double-click
```

```powershell
.\bh-agent-windows-x86_64-setup.exe              # Windows; see the Windows section
```

The `.deb` asks through **debconf**, so GNOME Software or `gdebi` draws the
form and the same questions appear in a terminal dialog over SSH. The `.pkg`
uses Installer.app for the install and native dialogs for the questions. One
`.pkg` covers Apple Silicon and Intel. The Windows installer is an Inno Setup
wizard; it is not Authenticode-signed, so expect the SmartScreen prompt
described under [Windows](#windows).

Verify the signature first — the same way as an archive, shown under
[Verify before installing](#verify-before-installing).

Each release also ships the bare binary (`<asset>.bin`) with its own
`.bin.sha256` and `.bin.sig.hex`. Those feed the agent's self-update endpoint
and are not needed for a manual install.

See [Changelog](#changelog) for what changed.

## Install

One-liner (detects OS/arch, downloads, **verifies the signature**, verifies the
checksum, installs):

```bash
curl -fsSL https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/get-agent.sh \
  | bash -s -- --token <DEVICE_TOKEN> --name "$(hostname)" --api https://edm.beehiveinteractive.net/api/v1
```

### Manual install

```bash
base=https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/releases/v1.7.0
curl -fsSLO $base/bh-agent-linux-x86_64.tar.gz
curl -fsSLO $base/bh-agent-linux-x86_64.tar.gz.sig
curl -fsSLO $base/bh-agent-linux-x86_64.tar.gz.sha256

# Verify the signature first — see "Verify before installing" below.
openssl pkeyutl -verify -pubin -inkey release.pub -rawin \
  -in bh-agent-linux-x86_64.tar.gz -sigfile bh-agent-linux-x86_64.tar.gz.sig
sha256sum -c bh-agent-linux-x86_64.tar.gz.sha256

tar -xzf bh-agent-linux-x86_64.tar.gz
sudo ./bh-agent-linux-x86_64/install.sh --token <DEVICE_TOKEN> --name "$(hostname)" --api https://edm.beehiveinteractive.net/api/v1
```

Swap the asset name for `bh-agent-macos-arm64.tar.gz` or
`bh-agent-macos-x86_64.tar.gz` on macOS.

Each archive contains the `bh-agent` binary, `install.sh`/`uninstall.sh`,
the systemd unit / launchd plist, and `config.example.yaml`.

### Verify before installing

**The signature is the security control — not the checksum.** The `.sha256`
file is served from the same host, over the same connection, as the archive it
describes, so it proves only that the download was not corrupted. Anyone able
to modify an artifact here could publish a matching checksum alongside it. The
Ed25519 signature is what they cannot forge, because the private key is held
offline and never touches this repository or CI on its own.

Release signing public key:

```
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAlzw3tswOq2KXFlTyRQELepHbhfuc89iNLUuIG8h41Ok=
-----END PUBLIC KEY-----
```

Verify a downloaded archive:

```bash
cat > release.pub <<'EOF'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAlzw3tswOq2KXFlTyRQELepHbhfuc89iNLUuIG8h41Ok=
-----END PUBLIC KEY-----
EOF

openssl pkeyutl -verify -pubin -inkey release.pub -rawin \
  -in bh-agent-linux-x86_64.tar.gz \
  -sigfile bh-agent-linux-x86_64.tar.gz.sig
```

Expect `Signature Verified Successfully`. Anything else: do not install.

> **macOS:** Apple ships LibreSSL as `/usr/bin/openssl`, and LibreSSL has no
> `-rawin`, so it cannot verify Ed25519 at all. Install a real OpenSSL with
> `brew install openssl@3` — `get-agent.sh` detects this and tells you, rather
> than reporting it as a failed signature.

The checksum is still worth running as a corruption check:

```bash
# Linux
sha256sum -c bh-agent-linux-x86_64.tar.gz.sha256

# macOS
shasum -a 256 -c bh-agent-macos-arm64.tar.gz.sha256
```

### macOS: Gatekeeper and downloaded files

If you obtain an archive through a **web browser** rather than `curl`, macOS
stamps every extracted file with `com.apple.quarantine`. The agent is not
notarized by Apple, so Gatekeeper kills it on launch — you get *"Apple could not
verify bh-agent is free of malware"* and the process dies with signal 9, with no
output at all.

`get-agent.sh` uses `curl`, which does not set that attribute, so a normal install
is unaffected. Git does not store extended attributes either, so files cloned from
this repo are clean. It only bites a browser download:

```bash
xattr -cr <extracted-directory>
```

## Upgrading an existing device

Re-run the same one-liner **with no `--token`, `--name` or `--api`**:

```bash
curl -fsSL https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/get-agent.sh | bash
```

Since v1.3.1 the installer detects an existing `config.yaml` and **preserves it** —
token, API URL, interval and any `screenshots` block are left alone; only the
binary and the service unit are replaced. That is why no token is needed. Pass
`--force-config` only when you deliberately want the configuration rewritten, for
example to rotate the token.

Since v1.6.0 an upgrade also **offers the reporting settings**, defaulted to what
the device is set to now: how often to report, whether to capture the screen, and
how often. Press Enter through them to change nothing — only a setting you
actually change is written, and it is written with `bh-agent config set`, which
edits that one line and leaves the token and everything else alone. Supply
`--interval`, `--screenshots`/`--no-screenshots` or `--screenshot-interval` to
answer non-interactively; with no terminal at all the current values are kept.

**`bh-agent update` does not work against the current platform.** It calls
`GET /devices/update`, which the platform does not implement, so the request 404s.
Upgrade with the one-liner above.

Verify afterwards:

```bash
bh-agent --version          # expect 1.7.0
bh-agent config check       # confirms the preserved config still validates
```

## Device reporting and screen capture

Two separate subsystems, two separate switches. Turning one off says nothing
about the other.

```bash
bh-agent metrics status              # is this device reporting?
bh-agent screenshots status          # is this device capturing?

sudo bh-agent metrics disable --restart   # stop reporting, stay registered
sudo bh-agent screenshots enable          # opt in to capture
```

Screen capture is **opt-in and disabled by default** (ADR-008). Upgrading
never turns it on. Device reporting stays on by default.

```bash
sudo bh-agent screenshots enable
sudo bh-agent screenshots install    # run via sudo from the account to capture
bh-agent screenshots status          # NOT under sudo — see below
```

Capture runs as a separate **per-user** service, because the root daemon has no
display access on either platform.

Run `bh-agent screenshots status` **without sudo**. Under sudo it reports root's
session and root's permission state, not the capture user's — which is misleading,
because the capture agent runs as the logged-in user.

Screenshots record whatever is on screen. If a device is used by someone else,
telling them is the operator's responsibility.

### macOS

Needs **Screen Recording** permission, which no API can grant — only the person at
the machine can:

System Settings > Privacy & Security > Screen Recording > **+** > `⌘⇧G` >
`/usr/local/bin/bh-agent` > enable the toggle. Then re-run
`sudo bh-agent screenshots install` to restart the capture agent.

Without it, macOS returns the desktop wallpaper with every other application's
windows stripped out — captures look valid but show nothing useful. Since
v1.3.1 the agent refuses to capture in that state rather than uploading
wallpaper (v1.2.0 uploaded it).

### Linux

Works on **both Wayland and Xorg** (ADR-009). Wayland goes through
`xdg-desktop-portal`, which a standard desktop install already provides
(`xdg-desktop-portal-gnome` on Ubuntu). The portal asks for consent the first
time and the desktop remembers the answer, so later captures are silent — the
consent token is stored (fixed in v1.3.1; v1.3.0 re-showed the picker dialog,
with a preview and sound, on every capture). The Wayland runtime packages
(`gstreamer1.0-pipewire`, `gstreamer1.0-plugins-good`) install automatically.

Ubuntu 26.04 ships GNOME 49+, which **removed the Xorg session entirely** — there
is no "Ubuntu on Xorg" option and none is needed. On Wayland the portal composites
all monitors into a single image, so multi-monitor devices report one display
rather than one per monitor; Xorg still reports each separately.

## Network reporting

Per interface: type (wifi/ethernet/bridge/virtual), IPv4 and IPv6, MAC,
throughput in bytes per second, and for wireless links the **SSID and signal
strength**. Plus the device's default routes, and its public IP as seen by the
platform.

> **SSID and public IP are location data.** A network name resolves to a
> street-level position through public wifi geolocation databases. This is
> collected by default (since v1.3.1).

## Windows

**Supported since v1.5.0, published here since v1.7.0.**

It registers as a real Windows Service through the SCM, ships a one-click
installer, restricts the queue database to SYSTEM and Administrators with an
explicit DACL, and captures screens. The feature set matches Linux and macOS
apart from the gaps listed below.

Two files, each with a `.sha256` and an Ed25519 `.sig` beside it:

- [bh-agent-windows-x86_64-setup.exe](releases/v1.7.0/bh-agent-windows-x86_64-setup.exe) — the installer; start here
- [bh-agent-windows-x86_64.exe](releases/v1.7.0/bh-agent-windows-x86_64.exe) — the bare agent, for running by hand

```powershell
.\bh-agent-windows-x86_64-setup.exe         # double-click; the wizard asks for everything
.\bh-agent-windows-x86_64-setup.exe /VERYSILENT /TOKEN=... /API=... /NAME=...   # unattended
```

They carry **no Authenticode signature** — there is no code-signing
certificate yet — so SmartScreen shows *"Windows protected your PC"* on first
run. Choose **More info → Run anyway**. That warning is about the absent
certificate, not about anything detected in the file; the Ed25519 signature
beside each file is what actually vouches for it (same verification as every
other artifact — OpenSSL 3 on Windows comes with Git for Windows, as
`"C:\Program Files\Git\usr\bin\openssl.exe"`).

Publishing unsigned Windows binaries next to artifacts an operator is told to
trust was previously avoided on purpose; it is now an explicit, accepted
tradeoff (v1.7.0) so Windows devices have a first-class download path.

Upgrading re-runs the same installer. It never asks for the token again — the
existing `config.yaml` is kept — but it does offer the reporting settings,
pre-filled with the device's current values.

> **Upgrading from a pre-v1.7.0 install** (one downloaded from the private
> repository's workflow artifacts): v1.7.0 regenerated the installer's
> product GUID, which had shipped as a placeholder. Windows therefore treats
> v1.7.0 as a new product — the old entry stays in "Apps" until you remove it
> once. Uninstall the old entry, then run the v1.7.0 installer; the device's
> `config.yaml` and identity survive, since uninstall leaves
> `%ProgramData%\bh-agent` in place.

### What still does not work on Windows

| | Status |
|---|---|
| Network SSID, signal, routes, interface type | The Windows provider returns nothing, and every interface reports type `other`. Names, addresses, MAC and throughput work. |
| CPU temperature | Always absent. Windows exposes no consistent source: the usual WMI route is unimplemented by many OEM firmwares, needs administrator rights, and often reports an ACPI zone rather than the CPU package. Reporting nothing is deliberate — a wrong number is worse than none. Same on macOS. |
| `bh-agent update` | Disabled in the agent on Windows. The updater's download path expects the `.bin` + `.sig.hex` asset shape, and Windows publishes `.exe` files with archive-style signatures instead. Upgrade by re-running the installer. |
| `get-agent.sh` | Unix only. There is no one-line curl install for Windows. |

## Changelog

Only the current release's artifacts are kept here (see "Older releases"
below for why). This log covers what changed release to release.

- **v1.7.0** — **Windows binaries are published here for the first time**:
  `bh-agent-windows-x86_64-setup.exe` and `bh-agent-windows-x86_64.exe`,
  Ed25519-signed like every other artifact but not Authenticode-signed — an
  explicit, accepted tradeoff so Windows devices get a first-class download
  path (SmartScreen prompts once; see the Windows section, including the
  one-time old-entry cleanup for devices installed from pre-1.7 workflow
  artifacts). The macOS installer's GUI is fixed: welcome and conclusion pages
  render as HTML again instead of raw source, and the brand mark — its black
  corners now transparent — sits as a small badge in the lower-left instead of
  filling the pane. The Windows wizard gained the same
  what-this-installs / what-it-never-collects page the macOS installer shows.
  Under the hood, a full-codebase audit hardened the agent: Windows
  private-file helpers refuse pre-planted NTFS reparse points (symlinks,
  junctions, mount points) before writing or applying a DACL; the daemon's
  Windows log directory is created with its restrictive ACL before the first
  log line; a failed hand-over of the per-user capture unit now fails the
  install loudly instead of leaving a service that never loads; and screen
  capture validates frame stride and buffer arithmetic before touching pixel
  memory.
- **v1.6.0** — **graphical installers for Ubuntu and macOS**: a `.deb` driven
  by debconf and a universal `.pkg` with native dialogs, both asking the same
  questions as the Windows wizard. First install now asks how often to report
  and whether to capture the screen, per subsystem, with capture defaulting to
  off; an upgrade offers those same settings pre-filled with the device's
  current values and writes only what changed, so the token, comments and any
  hand-tuned key survive. `device_id` is now **derived from the host's machine
  identity** rather than randomly generated, so a machine that is uninstalled
  and reinstalled comes back as the same device instead of one its existing
  token cannot register (an existing `state.json` is never recomputed, so
  devices already enrolled keep their ID). New `bh-agent config get` prints one
  setting for scripting. Also fixes a Windows installer script that had not
  compiled since v1.5.0.
- **v1.5.0** — **Windows became a real target.** Service registration through
  the SCM with a proper stop/shutdown handler, a one-click Inno Setup installer
  (GUI and silent), screen capture via GDI including multi-monitor and per-user
  provisioning, self-update with a rename-aside swap so a running `.exe` can be
  replaced, and — the change that unblocked deployment — an explicit DACL
  restricting the queue database to SYSTEM and Administrators. Also hardened
  everywhere: every spawned tool resolves to an absolute path instead of going
  through `PATH`, numeric config settings are bounded so a typo cannot stall or
  abort the daemon, and an unreadable queue row is parked rather than failing
  its whole batch. Not published here — see [Windows](#windows).
- **v1.4.0** — maintenance release, no runtime behavior change. Fixes a macOS
  CI build failure (`clippy::items_after_test_module` in
  `src/metrics/platform/macos.rs`) and updates install docs to reflect the
  public release channel: install resolves the version from
  `releases/latest.txt` and verifies an Ed25519 signature, not just a
  checksum; `python3` is no longer a prerequisite, an OpenSSL with `-rawin`
  support is.
- **v1.3.1** — Wayland screen capture now stores the ScreenCast portal's
  consent token, so GNOME's source-picker dialog (screen preview + sound)
  shows once instead of on every capture. Device reporting and screen capture
  got independent on/off switches (`metrics` vs `screenshots`); `screenshots
  disable` now actually stops capture (v1.3.0 restarted the root daemon,
  which does not capture, while the per-user capture service kept running).
  Added per-interface network detail: type, IPv4/IPv6, MAC, throughput, and
  for wireless links SSID + signal strength, plus default routes and public
  IP — SSID and public IP are location data and are collected by default.
  Also: `screenshots status` works for the ordinary user again (v1.3.0
  aborted with a permission error); Wayland runtime packages install
  automatically; a Wayland display no longer reports as `0x0`.
- **v1.3.0** — first Wayland capture, but it never stored the portal's consent
  token, so GNOME showed its source-picker dialog — screen preview and sound —
  on every capture rather than once. `screenshots disable` also did not stop
  capture: it restarted the root daemon, which does not capture, while the
  per-user service kept running. Both fixed in v1.3.1.
- **v1.2.0** — shipped screen capture with a macOS permission gate that had been
  weakened, so a Mac without Screen Recording consent uploaded pictures of the
  desktop wallpaper instead of the screen. Its per-user capture service also used
  a restart policy that respawned every 10 seconds forever on any device where
  capture could not run. Both fixed in v1.3.0.
- **v1.1.x and earlier** — predate screen capture, and the v1.1.0/v1.1.1
  installers rejected valid tokens or refused to install on Linux.

### Older releases

Only the current release is kept here. Earlier versions are removed rather than
left in place: every one of them either fails to install or predates a fix that
matters. If a device is still running an old release, upgrade from the current
release rather than trying to patch in place.

v1.5.0 was never published here — v1.6.0 supersedes it and includes everything
it shipped.

## What this repo does not contain

No application source code, no device tokens, no API credentials, and no
signing key. Only built binaries, their checksums, and their signatures.
