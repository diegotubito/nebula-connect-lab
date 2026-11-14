#!/bin/sh
# Install the authenticated archive as a separate, versioned CLI.
set -eu
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
unset NODE_OPTIONS NODE_PATH
[ "$(uname -s)" = Darwin ] && [ "$(id -u)" = 0 ] || { echo 'Run the installer with sudo on macOS.' >&2; exit 1; }
arch=$(uname -m)
if [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then arch=arm64; fi
case "$arch" in
  arm64) hash=9ca4a6ae49ed9910f04efc1f45b667402ce511233391d94695bab89992d63b57 ;;
  x86_64) hash=7da73cea6fab7155f3fa6481207ef993f342fc96a0f7d8aeb167d4d9f0c57de4 ;;
  *) exit 1 ;;
esac
dir=/Library/NebulaConnectReaders
bin=/usr/local/bin/nebula
version=mac-readers.1
mkdir -p "$dir" /usr/local/bin
lock="$dir/install.lock"
mkdir "$lock" || { echo 'An installation is already in progress.' >&2; exit 1; }
trap 'rm -rf "$lock"' EXIT
target=$(readlink "$bin" || true)
if [ -e "$bin" ] || [ -L "$bin" ]; then
 case "$target" in
  "$dir/$version/nebula"|/Library/NebulaConnectLab/active) ;;
  *) echo 'Another nebula command is installed. Inspect its path before proceeding.' >&2; exit 1 ;;
 esac
fi
curl --proto '=https' --proto-redir '=https' -fsSL "https://github.com/diegotubito/nebula-connect-lab/releases/download/$version/nebula-h6-$arch.tar.gz" -o "$lock/kit"
[ "$(shasum -a 256 "$lock/kit" | cut -d' ' -f1)" = "$hash" ] || { echo 'Package checksum mismatch.' >&2; exit 1; }
mkdir "$lock/release"
tar -xzf "$lock/kit" -C "$lock/release"
# A symlink in /usr/local/bin needs an absolute launcher for the versioned runtime.
mv "$lock/release/nebula" "$lock/release/run"
printf '#!/bin/sh\nexec "%s/%s/run" "$@"\n' "$dir" "$version" > "$lock/release/nebula"
chmod 755 "$lock/release/nebula"
if [ -d "$dir/$version" ]; then
 diff -qr "$lock/release" "$dir/$version" >/dev/null || { echo 'Installed release differs.' >&2; exit 1; }
else
 mv "$lock/release" "$dir/$version"
fi
ln -s "$dir/$version/nebula" "$lock/link"
mv -fh "$lock/link" "$bin"
echo 'Installed mac-readers.1. Run nebula list in your normal Terminal.'
