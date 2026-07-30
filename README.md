# bh-agent-releases

Public distribution point for prebuilt [Beehive Device Agent](https://beehiveinteractive.net) binaries.

The agent's source lives in a private repository. This repo carries only the
built, signed release artifacts so devices can install without a GitHub
access token.

## Latest release

**v1.3.1**

| Platform | Archive | Signature | Checksum |
|---|---|---|---|
| Linux x86_64 | [bh-agent-linux-x86_64.tar.gz](releases/v1.3.1/bh-agent-linux-x86_64.tar.gz) | [.sig](releases/v1.3.1/bh-agent-linux-x86_64.tar.gz.sig) | [.sha256](releases/v1.3.1/bh-agent-linux-x86_64.tar.gz.sha256) |
| macOS Apple Silicon | [bh-agent-macos-arm64.tar.gz](releases/v1.3.1/bh-agent-macos-arm64.tar.gz) | [.sig](releases/v1.3.1/bh-agent-macos-arm64.tar.gz.sig) | [.sha256](releases/v1.3.1/bh-agent-macos-arm64.tar.gz.sha256) |
| macOS Intel | [bh-agent-macos-x86_64.tar.gz](releases/v1.3.1/bh-agent-macos-x86_64.tar.gz) | [.sig](releases/v1.3.1/bh-agent-macos-x86_64.tar.gz.sig) | [.sha256](releases/v1.3.1/bh-agent-macos-x86_64.tar.gz.sha256) |

Each release also ships the bare binary (`<asset>.bin`) with its own
`.bin.sha256` and `.bin.sig.hex`. Those feed the agent's self-update endpoint
and are not needed for a manual install.

## Verify before installing

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

## Install

One-liner (detects OS/arch, downloads, **verifies the signature**, verifies the
checksum, installs):

```bash
curl -fsSL https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/get-agent.sh \
  | bash -s -- --token <DEVICE_TOKEN> --name "$(hostname)" --api https://edm.beehiveinteractive.net/api/v1
```

### Manual install

```bash
base=https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/releases/v1.3.1
curl -fsSLO $base/bh-agent-linux-x86_64.tar.gz
curl -fsSLO $base/bh-agent-linux-x86_64.tar.gz.sig
curl -fsSLO $base/bh-agent-linux-x86_64.tar.gz.sha256

# Verify the signature first — see "Verify before installing" above.
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

## Upgrading an existing device

Re-run the same one-liner **with no `--token`, `--name` or `--api`**:

```bash
curl -fsSL https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/get-agent.sh | bash
```

From v1.3.1 the installer detects an existing `config.yaml` and **preserves it** —
token, API URL, interval and any `screenshots` block are left alone; only the
binary and the service unit are replaced. That is why no token is needed. Pass
`--force-config` only when you deliberately want the configuration rewritten, for
example to rotate the token.

**`bh-agent update` does not work against the current platform.** It calls
`GET /devices/update`, which the platform does not implement, so the request 404s.
Upgrade with the one-liner above.

Verify afterwards:

```bash
bh-agent --version          # expect 1.3.1
bh-agent config check       # confirms the preserved config still validates
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

## What is new in v1.3.1

Three things: Wayland screen capture that is actually **silent**, independent
on/off switches for the two subsystems, and much richer network reporting.

### Screen capture is silent now

v1.3.0 shipped Wayland capture through the ScreenCast portal, but it never
stored the consent token the portal handed back — so GNOME re-ran its
source-picker dialog, with a preview of your screen and a notification sound,
**on every single capture**. v1.3.1 stores it. The first capture after
upgrading asks once; every one after that is silent.

### Two independent switches

Device reporting and screen capture are separate subsystems and now have
separate switches. Turning one off says nothing about the other.

```bash
bh-agent metrics status              # is this device reporting?
bh-agent screenshots status          # is this device capturing?

sudo bh-agent metrics disable --restart   # stop reporting, stay registered
sudo bh-agent screenshots enable          # opt in to capture
```

`screenshots disable` now actually stops capture. In v1.3.0 it wrote the daemon
config and restarted the root daemon — which does not capture — while the
per-user capture service carried on running. If you relied on it to stop
capture on a device, **it did not**.

`--restart` is no longer needed on `screenshots enable`/`disable`; both apply
immediately. The flag is still accepted and ignored.

### Network reporting

Per interface: type (wifi/ethernet/bridge/virtual), IPv4 and IPv6, MAC,
throughput in bytes per second, and for wireless links the **SSID and signal
strength**. Plus the device's default routes, and its public IP as seen by the
platform.

> **SSID and public IP are location data.** A network name resolves to a
> street-level position through public wifi geolocation databases. This is
> collected by default in v1.3.1.

### Also fixed

- `bh-agent screenshots status` works for the ordinary user it is meant for. In
  v1.3.0 it aborted with a permission error before printing anything, while the
  root-run output told you to run exactly that command.
- The Wayland runtime packages (`gstreamer1.0-pipewire`,
  `gstreamer1.0-plugins-good`) install automatically. v1.3.0 needed a manual
  `apt install` that was not documented anywhere.
- A Wayland display no longer reports as `0x0` — the portal does not enumerate
  screens, and that zero read as a broken display.

### Upgrade notes

Screen capture stays opt-in and **disabled by default** (ADR-008). Upgrading
does not enable it. Device reporting stays on, as before.

```bash
sudo bh-agent screenshots enable
sudo bh-agent screenshots install    # run via sudo from the account to capture
bh-agent screenshots status          # NOT under sudo — see below
```

Capture runs as a separate **per-user** service, because the root daemon has no
display access on either platform.

### macOS

Needs **Screen Recording** permission, which no API can grant — only the person at
the machine can:

System Settings > Privacy & Security > Screen Recording > **+** > `⌘⇧G` >
`/usr/local/bin/bh-agent` > enable the toggle. Then re-run
`sudo bh-agent screenshots install` to restart the capture agent.

Without it, macOS returns the desktop wallpaper with every other application's
windows stripped out — captures look valid but show nothing useful. v1.3.1 refuses
to capture in that state rather than uploading wallpaper; v1.2.0 uploaded it.

### Linux

Works on **both Wayland and Xorg** (ADR-009). Wayland goes through
`xdg-desktop-portal`, which a standard desktop install already provides
(`xdg-desktop-portal-gnome` on Ubuntu). The portal asks for consent the first time
and the desktop remembers the answer, so later captures are silent.

Ubuntu 26.04 ships GNOME 49+, which **removed the Xorg session entirely** — there
is no "Ubuntu on Xorg" option and none is needed. On Wayland the portal composites
all monitors into a single image, so multi-monitor devices report one display
rather than one per monitor; Xorg still reports each separately.

### Checking status

Run `bh-agent screenshots status` **without sudo**. Under sudo it reports root's
session and root's permission state, not the capture user's — which is misleading,
because the capture agent runs as the logged-in user.

### Fixed since v1.2.0

- macOS: refuses to capture without Screen Recording consent, instead of uploading
  wallpaper-only frames
- macOS: `screenshots install` now loads the capture agent correctly (v1.2.0 failed
  with `Bootstrap failed: 5`)
- The per-user service no longer respawns every 10 seconds on devices where capture
  cannot run; one v1.2.0 device reached 345 restarts
- Session detection no longer mistakes a Wayland desktop for Xorg when run under
  sudo

Screenshots record whatever is on screen. If a device is used by someone else,
telling them is the operator's responsibility.

## Windows

**Not supported. Do not deploy.**

No Windows build is published here, and that is deliberate rather than an
oversight. CI does compile and test a Windows binary, but it is retained only as
an internal-testing artifact and is deliberately excluded from every release —
publishing it alongside the supported builds would invite someone to deploy it.

The blocking gap is file access control. The agent applies Unix permissions
only, so on Windows the queue database inherits whatever `%ProgramData%` grants
and is **readable by every local user**. That database holds a rolling multi-day
record of every process on the host, including other users' names and executable
paths. Windows also has no service registration (it cannot run as a Windows
service), no installer, and `bh-agent update` refuses to run.

Use Linux or macOS for anything real. Windows support is planned; it is not
ready.

### Running it on Windows anyway, to test

There is no installer and no service, so a Windows run is a foreground process
you start yourself and stop with Ctrl-C. Use a scratch machine or VM, not
anything with other people's data on it — the queue database limitation below
is not theoretical.

**1. Get the binary.** It is not published here. Take it from the Actions run
for the release tag, under Artifacts, named
`UNSUPPORTED-windows-x86_64-internal-testing` — it contains `bh-agent.exe` and
an `UNSUPPORTED.txt` restating these limits. Or build it yourself on the
Windows box:

```powershell
cargo build --release --target x86_64-pc-windows-msvc
```

**2. Write a config.** The agent looks in `%ProgramData%\bh-agent\config.yaml`
by default. In PowerShell **as Administrator**:

```powershell
New-Item -ItemType Directory -Force "$env:ProgramData\bh-agent" | Out-Null
@"
api:
  base_url: https://edm.beehiveinteractive.net/api/v1
  timeout_seconds: 30
  token: bh_live_replace_me
agent:
  name: $env:COMPUTERNAME
  interval_minutes: 5
logging:
  level: info
"@ | Set-Content -Encoding utf8 "$env:ProgramData\bh-agent\config.yaml"
```

**3. Check it parses, then run it.**

```powershell
.\bh-agent.exe config check
.\bh-agent.exe
```

`config check` prints the effective settings and exits — do that first, because
a bad config is the most common reason the agent appears to start and then
stops. `state.json` and `queue.sqlite` are written next to the config.

**What will not work, by design:**

| | Why |
|---|---|
| Running as a service | No Service Control Manager registration. Closing the console stops the agent. |
| `bh-agent update` | Refuses on Windows — `updater::supported()` returns false. |
| `bh-agent screenshots *` | Per-user capture is systemd/launchd only. Reports unsupported and exits. |
| Network SSID / routes | The Windows provider returns nothing. Interface names, addresses, MAC and throughput still work. |
| File permissions | **The real blocker.** `queue.sqlite` inherits `%ProgramData%` and is readable by every local account. It holds a rolling multi-day record of every process on the host, including other users' names and executable paths. |

What you *can* usefully test: registration, the report payload, CPU/memory/disk
metrics, the offline queue and its retry behaviour, and the process list.

## Older releases

Only the current release is kept here. Earlier versions are removed rather than
left in place: every one of them either fails to install or predates a fix that
matters.

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

If a device is still running one of these, upgrade from the current release
rather than trying to patch in place.

## What this repo does not contain

No application source code, no device tokens, no API credentials, and no
signing key. Only built binaries, their checksums, and their signatures.
