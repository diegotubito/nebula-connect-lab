#!/bin/sh
# Keep all executable steps inside main so a truncated download cannot start installation.
main() {
    set -eu
    export PATH=/usr/bin:/bin:/usr/sbin:/sbin
    fail() { echo "No se pudo instalar Nebula Connect: $*" >&2; exit 1; }
    [ "$(uname -s)" = Darwin ] || fail 'se requiere macOS.'
    [ "$(id -u)" = 0 ] || fail 'ejecutá el comando con sudo.'
    arch=$(uname -m)
    if [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then arch=arm64; fi
    case "$arch" in
        arm64) hash=a140a68400e463bff12d2f1e68423369d607a77b9e5ba1d6e608429aaba66c70 ;;
        x86_64) hash=2e551aa4b8bc7f136c7dfee33cce5359cfaafabec353f748eaa77dd23d2f9dd0 ;;
        *) fail "arquitectura incompatible ($arch)." ;;
    esac
    base=https://github.com/diegotubito/nebula-connect-lab/releases/download
    dir=$(mktemp -d /private/tmp/nebula-install.XXXXXXXX) || fail 'no se pudo preparar la descarga.'
    trap 'rm -rf "$dir"' EXIT
    curl --proto '=https' --proto-redir '=https' -fsSL "$base/lab-0.2.0/macos-$arch-install.sh" -o "$dir/install.sh" || fail 'falló la descarga.'
    actual=$(shasum -a 256 "$dir/install.sh" | cut -d' ' -f1)
    [ "$actual" = "$hash" ] || fail 'falló la verificación del instalador.'
    /usr/bin/arch "-$arch" /bin/sh "$dir/install.sh" install 0.2.0 "$base" || fail 'revisá el error anterior, los permisos y si hay otro Connect instalado.'
    version=$(/usr/local/bin/nebula --version) || fail 'no se pudo consultar la versión.'
    case "$version" in 0.2.0|0.2.1) echo "Nebula Connect $version instalado." ;; *) fail 'versión inesperada.' ;; esac
}
main
