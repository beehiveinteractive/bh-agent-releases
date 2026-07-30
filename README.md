# bh-agent-releases

Public distribution point for prebuilt [Beehive Device Agent](https://beehiveinteractive.net) binaries.

The agent's source lives in a private repository. This repo carries only the
built, signed release artifacts so devices can install without a GitHub
access token.

## Latest release

**v1.2.0**

| Platform | Archive | Signature | Checksum |
|---|---|---|---|
| Linux x86_64 | [bh-agent-linux-x86_64.tar.gz](releases/v1.2.0/bh-agent-linux-x86_64.tar.gz) | [.sig](releases/v1.2.0/bh-agent-linux-x86_64.tar.gz.sig) | [.sha256](releases/v1.2.0/bh-agent-linux-x86_64.tar.gz.sha256) |
| macOS Apple Silicon | [bh-agent-macos-arm64.tar.gz](releases/v1.2.0/bh-agent-macos-arm64.tar.gz) | [.sig](releases/v1.2.0/bh-agent-macos-arm64.tar.gz.sig) | [.sha256](releases/v1.2.0/bh-agent-macos-arm64.tar.gz.sha256) |
| macOS Intel | [bh-agent-macos-x86_64.tar.gz](releases/v1.2.0/bh-agent-macos-x86_64.tar.gz) | [.sig](releases/v1.2.0/bh-agent-macos-x86_64.tar.gz.sig) | [.sha256](releases/v1.2.0/bh-agent-macos-x86_64.tar.gz.sha256) |

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
base=https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/releases/v1.2.0
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

From v1.2.0 the installer detects an existing `config.yaml` and **preserves it** —
token, API URL, interval and any `screenshots` block are left alone; only the
binary and the service unit are replaced. That is why no token is needed. Pass
`--force-config` only when you deliberately want the configuration rewritten, for
example to rotate the token.

**`bh-agent update` does not work against the current platform.** It calls
`GET /devices/update`, which the platform does not implement, so the request 404s.
Upgrade with the one-liner above.

Verify afterwards:

```bash
bh-agent --version          # expect 1.2.0
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

## What is new in v1.2.0

Opt-in periodic **screen capture** (ADR-008), disabled by default. Upgrading does
not enable it: a config with no `screenshots` block defaults to off.

To turn it on, on a Mac or an Xorg Linux session:

```bash
sudo bh-agent screenshots enable --restart
sudo bh-agent screenshots install    # run via sudo from the account to capture
bh-agent screenshots status          # session, permission, displays, spool
```

Capture runs as a separate **per-user** service, because the root daemon has no
display access on either platform. On macOS it additionally needs Screen Recording
permission, which only the person at the machine can grant, in System Settings >
Privacy & Security > Screen Recording. On Linux it needs an **Xorg** session;
Wayland is detected and skipped.

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

Use Linux or macOS. Windows support is planned; it is not ready.

## Older releases

The previous release, **v1.1.2**, is still present so a device can be rolled
back. Anything older has been removed rather than left in place, because every
one of those versions fails to install:

- **v1.1.1** — the installer's root-ownership check used BSD `stat` syntax and
  misread its own output on Linux, so it refused to install on every Linux
  machine. Fixed in v1.1.2.
- **v1.1.0** — the installer rejected every valid device token: a character
  range was evaluated in collation order rather than ASCII order, so under any
  UTF-8 locale it treated ordinary alphanumerics as non-printable. `--token`,
  `--token-file` and `BH_AGENT_SETUP_TOKEN` were all affected. Fixed in v1.1.1.
- **v1.0.x** — predates release signing and shipped checksums only.
  `get-agent.sh` refuses to install anything unsigned.

If a device is still running one of these, reinstall from the current release
rather than trying to upgrade in place.

## What this repo does not contain

No application source code, no device tokens, no API credentials, and no
signing key. Only built binaries, their checksums, and their signatures.
