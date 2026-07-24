# bh-agent-releases

Public distribution point for prebuilt [Beehive Device Agent](https://beehiveinteractive.net) binaries.

The agent's source lives in a private repository. This repo carries only the
built, checksummed release artifacts so devices can install without a GitHub
access token.

## Latest release

**v1.0.3**

| Platform | Archive | Checksum |
|---|---|---|
| Linux x86_64 | [bh-agent-linux-x86_64.tar.gz](releases/v1.0.3/bh-agent-linux-x86_64.tar.gz) | [.sha256](releases/v1.0.3/bh-agent-linux-x86_64.tar.gz.sha256) |
| macOS Apple Silicon | [bh-agent-macos-arm64.tar.gz](releases/v1.0.3/bh-agent-macos-arm64.tar.gz) | [.sha256](releases/v1.0.3/bh-agent-macos-arm64.tar.gz.sha256) |
| macOS Intel | [bh-agent-macos-x86_64.tar.gz](releases/v1.0.3/bh-agent-macos-x86_64.tar.gz) | [.sha256](releases/v1.0.3/bh-agent-macos-x86_64.tar.gz.sha256) |

## Verify before installing

Each archive ships with a `.sha256` checksum file. Verify before extracting:

```bash
# Linux
sha256sum -c bh-agent-linux-x86_64.tar.gz.sha256

# macOS
shasum -a 256 -c bh-agent-macos-arm64.tar.gz.sha256
```

## Install

One-liner (detects OS/arch, downloads, verifies checksum, installs):

```bash
curl -fsSL https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/get-agent.sh \
  | bash -s -- --token <DEVICE_TOKEN> --name "$(hostname)" --api https://edm.beehiveinteractive.net/api/v1
```

### Manual install

```bash
curl -fsSLO https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/releases/v1.0.3/bh-agent-linux-x86_64.tar.gz
curl -fsSLO https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/releases/v1.0.3/bh-agent-linux-x86_64.tar.gz.sha256
sha256sum -c bh-agent-linux-x86_64.tar.gz.sha256
tar -xzf bh-agent-linux-x86_64.tar.gz
sudo ./bh-agent-linux-x86_64/install.sh --token <DEVICE_TOKEN> --name "$(hostname)" --api https://edm.beehiveinteractive.net/api/v1
```

Swap the asset name for `bh-agent-macos-arm64.tar.gz` or
`bh-agent-macos-x86_64.tar.gz` on macOS.

Each archive contains the `bh-agent` binary, `install.sh`/`uninstall.sh`,
the systemd unit / launchd plist, and `config.example.yaml`.

## What this repo does not contain

No application source code, no device tokens, no API credentials. Only
built binaries and their checksums.
