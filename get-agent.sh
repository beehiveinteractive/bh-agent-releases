#!/usr/bin/env bash
# Downloads and installs the latest bh-agent release for the current OS/arch.
# This repo is public: no token needed.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/beehiveinteractive/bh-agent-releases/main/get-agent.sh \
#     | bash -s -- --token <DEVICE_TOKEN> --name <NAME> --api <API_URL>
set -euo pipefail

REPO="beehiveinteractive/bh-agent-releases"
RAW_BASE="https://raw.githubusercontent.com/$REPO/main"

for dep in curl tar; do
  command -v "$dep" >/dev/null 2>&1 || { echo "missing required command: $dep" >&2; exit 1; }
done

# sha256sum (coreutils) is standard on Linux; shasum (perl) is standard on
# macOS. Both read/write the same "<hash>  <file>" checksum format.
if command -v sha256sum >/dev/null 2>&1; then
  sha256_check() { sha256sum -c "$1"; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_check() { shasum -a 256 -c "$1"; }
else
  echo "missing required command: sha256sum or shasum" >&2
  exit 1
fi

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux)
    case "$arch" in
      x86_64) asset="bh-agent-linux-x86_64" ;;
      *) echo "unsupported Linux architecture: $arch" >&2; exit 1 ;;
    esac
    ;;
  Darwin)
    case "$arch" in
      arm64)  asset="bh-agent-macos-arm64" ;;
      x86_64) asset="bh-agent-macos-x86_64" ;;
      *) echo "unsupported macOS architecture: $arch" >&2; exit 1 ;;
    esac
    ;;
  *) echo "unsupported OS: $os" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Looking up latest version..."
curl -fsSL "$RAW_BASE/releases/latest.txt" -o "$tmp/latest.txt"
version="$(tr -d '[:space:]' < "$tmp/latest.txt")"
if [[ -z "$version" ]]; then
  echo "could not determine latest version" >&2
  exit 1
fi

version_base="$RAW_BASE/releases/$version"

echo "Downloading $asset ($version)..."
curl -fsSL "$version_base/$asset.tar.gz" -o "$tmp/$asset.tar.gz"
curl -fsSL "$version_base/$asset.tar.gz.sha256" -o "$tmp/$asset.tar.gz.sha256"

echo "Verifying checksum..."
(cd "$tmp" && sha256_check "$asset.tar.gz.sha256")

tar -xzf "$tmp/$asset.tar.gz" -C "$tmp"

echo "Running installer (requires sudo)..."
exec sudo "$tmp/$asset/install.sh" "$@"
