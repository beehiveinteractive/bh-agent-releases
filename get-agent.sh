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

# Ed25519 public key for release signatures. The matching private key is held
# offline, outside this repository and outside CI's reach on its own — so write
# access to this repo is not sufficient to forge a release. Replacing this key
# is a deliberate, reviewed change: anyone who can edit it can install arbitrary
# code as root on every device.
RELEASE_PUBKEY="-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAlzw3tswOq2KXFlTyRQELepHbhfuc89iNLUuIG8h41Ok=
-----END PUBLIC KEY-----"

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

# macOS ships Apple's LibreSSL as `openssl`, whose pkeyutl has no `-rawin` and
# so cannot verify Ed25519 at all. Probing for a capable binary keeps a missing
# tool from being reported as a failed signature — the two need very different
# responses: install OpenSSL 3.x, versus do not install this artifact.
OPENSSL=""
for candidate in openssl /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl; do
  command -v "$candidate" >/dev/null 2>&1 || continue
  # Captured rather than piped to grep: `-help` exits non-zero, which `pipefail`
  # would report as a probe failure.
  openssl_help="$("$candidate" pkeyutl -help 2>&1 || true)"
  case "$openssl_help" in
    *-rawin*) OPENSSL="$candidate"; break ;;
  esac
done
if [[ -z "$OPENSSL" ]]; then
  echo "FATAL: no OpenSSL with Ed25519 support ('-rawin') was found." >&2
  echo "Apple's bundled LibreSSL cannot verify release signatures. Install a" >&2
  echo "real OpenSSL and re-run:  brew install openssl@3" >&2
  echo "Refusing to install unverified code as root." >&2
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

# The checksum is fetched from the same host, over the same connection, as the
# artifact — so it proves only that the bytes were not corrupted in transit. It
# is worth nothing against anyone who can write to this repository. The
# signature is the control that matters, so it is checked first and its absence
# is fatal rather than skippable.
echo "Verifying signature..."
if ! curl -fsSL "$version_base/$asset.tar.gz.sig" -o "$tmp/$asset.tar.gz.sig"; then
  echo "FATAL: release $version is not signed ($asset.tar.gz.sig missing)." >&2
  echo "Releases before v1.1.0 predate signing and cannot be installed by this" >&2
  echo "script. Refusing to install unverified code as root." >&2
  exit 1
fi
printf '%s\n' "$RELEASE_PUBKEY" > "$tmp/release.pub"
if ! "$OPENSSL" pkeyutl -verify -pubin -inkey "$tmp/release.pub" \
      -rawin -in "$tmp/$asset.tar.gz" -sigfile "$tmp/$asset.tar.gz.sig" >/dev/null 2>&1; then
  echo "FATAL: release signature verification FAILED for $asset.tar.gz." >&2
  echo "Do not install. Report this immediately." >&2
  exit 1
fi
echo "signature OK"

echo "Verifying checksum..."
(cd "$tmp" && sha256_check "$asset.tar.gz.sha256")

tar -xzf "$tmp/$asset.tar.gz" -C "$tmp"

echo "Running installer (requires sudo)..."
exec sudo "$tmp/$asset/install.sh" "$@"
