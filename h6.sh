#!/bin/sh
main() {
    set -eu
    export PATH=/usr/bin:/bin:/usr/sbin:/sbin
    unset NODE_OPTIONS NODE_PATH
    [ "$(uname -s)" = Darwin ] && [ "$(id -u)" != 0 ] || { echo 'Usá Terminal de macOS con tu usuario.' >&2; exit 1; }
    arch=$(uname -m)
    if [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then arch=arm64; fi
    case "$arch" in
        arm64) hash=e734a7fbee14aafa9bd7fc16e127b6d1e7140395b5567d1f5e05a05e9a3b4257 ;;
        x86_64) hash=ed5fc88cfccdaf3f3de2a5066a965d36350950b1510c91cad80e645c7e3ac5c8 ;;
        *) echo 'Arquitectura desconocida.' >&2; exit 1 ;;
    esac
    umask 077
    dir=$(mktemp -d /private/tmp/nebula-h6-kit.XXXXXXXX)
    trap 'rm -rf "$dir"' EXIT
    curl --proto '=https' --proto-redir '=https' -fsSL "https://github.com/diegotubito/nebula-connect-lab/releases/download/h6-mac.1/nebula-h6-$arch.tar.gz" -o "$dir/kit"
    [ "$(shasum -a 256 "$dir/kit" | cut -d' ' -f1)" = "$hash" ] || { echo 'Falló la verificación del paquete.' >&2; exit 1; }
    tar -xzf "$dir/kit" -C "$dir"
    "$dir/nebula" "${@:-rehearse}"
}
main "$@"
