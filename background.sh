#!/bin/sh
# One verified bootstrap for the current user's launchd session.
(
set -eu
umask 077
d=$(mktemp -d /private/tmp/nebula-background.XXXXXXXX)
trap 'rm -rf "$d"' EXIT
curl --proto '=https' --proto-redir '=https' -fsSL https://github.com/diegotubito/nebula-connect-lab/releases/download/mac-readers.2/install.sh -o "$d/install.sh"
[ "$(shasum -a 256 "$d/install.sh" | cut -d' ' -f1)" = "115233dd73c2422385ea9abc053dab2d9605fb785836a03a61c73945261dfb8c" ] || { echo 'Installer checksum mismatch.' >&2; exit 1; }
/bin/sh "$d/install.sh"
)
