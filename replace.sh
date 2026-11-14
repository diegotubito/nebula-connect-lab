#!/bin/sh
# Opt-in bootstrap for an unassigned Mac. Keep the ordinary approval channel intact.
set -eu
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
unset NODE_OPTIONS NODE_PATH NEBULA_MAC_SESSION NEBULA_MAC_LOCKED
umask 077
[ "$(uname -s)" = Darwin ] && [ "$(id -u)" != 0 ] || exit 1
data="$HOME/Library/Application Support/NebulaConnectReaders"
root="$data/runtime"
for profile in "$HOME/Library/Application Support"/NebulaFacialSync-*; do
  [ ! -e "$profile" ] || { echo 'This Mac already has a sync installation.' >&2; exit 1; }
done
[ ! -e "$data/group.json" ] || { echo 'This Mac already has a group.' >&2; exit 1; }
if [ -e "$data/readers.json" ]; then
  [ -x "$root/active/node" ] && "$root/active/node" -e 'const r=JSON.parse(require("node:fs").readFileSync(process.argv[1]));if(!Array.isArray(r)||r.length)process.exit(1)' "$data/readers.json" || { echo 'This Mac already has readers.' >&2; exit 1; }
fi
d=$(mktemp -d /private/tmp/nebula-replace.XXXXXXXX)
trap 'rm -rf "$d"' EXIT
fetch(){ curl --proto '=https' --proto-redir '=https' -fsSL "$1" -o "$2"; }
base=https://raw.githubusercontent.com/diegotubito/nebula-connect-lab/ce4615462dacbbfe9cd4a411fe7dd3a64328c119
if [ ! -f "$data/machine-mode" ]; then
  if [ ! -e "$root/active" ]; then fetch "$base/background.sh" "$d/background.sh"; /bin/sh "$d/background.sh"; fi
  fetch "$base/machine.sh" "$d/machine.sh"; /bin/sh "$d/machine.sh"
fi
label=system/cloud.nebulacontrol.connect.machine
launchctl print "$label" >/dev/null
arch=$(uname -m)
if [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then arch=arm64; fi
case "$arch" in arm64) hash=f158e792a8d8035b1c79430669b778b535e35625c568e0a9f4e51a500635ed2a;; x86_64) hash=1b68d00ba999507275d62befced60cc626251dbadb6b6d6677838af33c0567d4;; *) exit 1;; esac
version=mac-readers.5
fetch "https://github.com/diegotubito/nebula-connect-lab/releases/download/replace.1/nebula-h6-$arch.tar.gz" "$d/kit.tgz"
[ "$(shasum -a 256 "$d/kit.tgz" | cut -d' ' -f1)" = "$hash" ] || { echo 'Package checksum mismatch.' >&2; exit 1; }
mkdir "$d/kit"; tar -xzf "$d/kit.tgz" -C "$d/kit"
if [ -d "$root/versions/$version" ]; then diff -qr "$d/kit" "$root/versions/$version" >/dev/null; else mv "$d/kit" "$root/versions/$version"; fi
old=$(readlink "$root/active")
case "$old" in versions/mac-readers.4|versions/mac-readers.5) ;; *) echo 'Unsupported current release.' >&2; exit 1;; esac
if [ "$old" != "versions/$version" ]; then
  sudo -v
  ln -s "versions/$version" "$d/link"; mv -fh "$d/link" "$root/active"
  # The existing supervisor finishes its active cycle on SIGTERM. KeepAlive loads the selected release.
  sudo /bin/launchctl kill SIGTERM "$label"
fi
for i in $(jot 45); do
  if "$root/nebula" status | grep -q "Machine service running | worker $version "; then
    "$root/nebula" replace </dev/tty; exit
  fi
  sleep 1
done
echo 'Machine worker did not confirm startup.' >&2; exit 1
