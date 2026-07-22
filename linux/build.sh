#!/bin/bash
trap "exit" INT
set -eux

# Flutter version to build with; override with the FLUTTER_VERSION env var.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.6}"

# --no-enforce-lockfile: resolve dependencies fresh rather than failing when pubspec.lock
# is out of date. For local builds right after bumping a git dependency ref, where the
# lockfile is knowingly stale. CI should never pass this — enforcement is what makes its
# builds reproducible.
ENFORCE_LOCKFILE=--enforce-lockfile
for arg in "$@"; do
    case "$arg" in
        --no-enforce-lockfile) ENFORCE_LOCKFILE= ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

cd "$(dirname "$0")/.."

# Switch the project to the pinned Flutter version via fvm.
# Set FLUTTER_CMD to bypass fvm and use a preinstalled Flutter instead.
if [ -z ${FLUTTER_CMD+x} ]; then
    fvm use "$FLUTTER_VERSION" --force
    FLUTTER_CMD="fvm flutter"
fi

# Clean the bundle output first: the tarball packages it wholesale, so
# leftover libs from removed plugins would get shipped.
rm -rf build/linux

$FLUTTER_CMD pub get $ENFORCE_LOCKFILE
# --no-pub: reuse the resolution performed above (build otherwise re-runs pub get with
# different flags).
$FLUTTER_CMD build linux --release -v --no-pub

arch=$(uname -m)
if [[ $arch == "x86_64" ]]; then
    folder="x64"
elif [[ $arch == "aarch64" ]]; then
    folder="arm64"
fi

# Inject version number into version.json
tmp=$(mktemp)
chmod 644 "$tmp"
jq '.version = "1.15.104.0"' build/linux/$folder/release/bundle/data/flutter_assets/version.json > "$tmp" && mv "$tmp" build/linux/$folder/release/bundle/data/flutter_assets/version.json
chmod +x build/linux/$folder/release/bundle/bluebubbles

tar czvf bluebubbles-linux-"$arch".tar.gz -C build/linux/$folder/release/bundle .
sha256sum bluebubbles-linux-"$arch".tar.gz
