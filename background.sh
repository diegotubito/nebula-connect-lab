#!/bin/sh
# One verified bootstrap for the current user's launchd session.
(
set -eu
umask 077
d=$(mktemp -d /private/tmp/nebula-background.XXXXXXXX)
trap 'rm -rf "$d"' EXIT
curl --proto '=https' --proto-redir '=https' -fsSL https://github.com/diegotubito/nebula-connect-lab/releases/download/mac-readers.2/setup.sh -o "$d/install.sh"
[ "$(shasum -a 256 "$d/install.sh" | cut -d' ' -f1)" = "ff9626811e4f30d8d613f9cdcc28884efc13ce1448c96eb38f5356c9e13fa2dc" ] || { echo 'Installer checksum mismatch.' >&2; exit 1; }
/bin/sh "$d/install.sh"
)
