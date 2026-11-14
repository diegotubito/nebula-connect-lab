#!/bin/sh
# One verified bootstrap for the current user's launchd session.
(
set -eu
umask 077
d=$(mktemp -d /private/tmp/nebula-background.XXXXXXXX)
trap 'rm -rf "$d"' EXIT
curl --proto '=https' --proto-redir '=https' -fsSL https://github.com/diegotubito/nebula-connect-lab/releases/download/mac-readers.4/machine-install.sh -o "$d/install.sh"
[ "$(shasum -a 256 "$d/install.sh" | cut -d' ' -f1)" = "05f3803a848bb160aeecf002621d734d6bb3129bf0cc37293871283ae7600523" ] || { echo 'Installer checksum mismatch.' >&2; exit 1; }
/bin/sh "$d/install.sh"
)
