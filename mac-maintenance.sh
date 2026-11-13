#!/bin/sh
main() {
  set -eu
  export PATH=/usr/bin:/bin:/usr/sbin:/sbin
  fail() { echo "Nebula Connect: $*" >&2; exit 1; }
  [ "$(uname -s)" = Darwin ] && [ "$(id -u)" = 0 ] || fail 'se requiere macOS y sudo.'
  root=/Library/NebulaConnectLab
  bin=/usr/local/bin/nebula
  [ -d "$root" ] && [ ! -L "$root" ] && [ "$(readlink "$bin")" = "$root/active" ] || fail 'instalación de laboratorio no reconocida.'
  case "$(readlink "$root/active")" in "$root/0.2.0/nebula"|"$root/0.2.1/nebula") ;; *) fail 'versión activa desconocida.' ;; esac
  mkdir "$root/lock" || fail 'hay otra operación en curso.'
  trap 'rmdir "$root/lock" 2>/dev/null || true' EXIT
  digest() { shasum -a 256 "$1" | cut -d' ' -f1; }
  case "$(digest "$root/manage.sh")" in
    a140a68400e463bff12d2f1e68423369d607a77b9e5ba1d6e608429aaba66c70|2e551aa4b8bc7f136c7dfee33cce5359cfaafabec353f748eaa77dd23d2f9dd0) patched=0 ;;
    800a880844c4af30b51bc2d2ea2632cf9ea278cd68cfb7ea0e037d122d4b6bf3|bea5c10d4450c5a3d55159a142805ca6e1fb029cb1bf59b024adf0432a2c994d) patched=1 ;;
    *) fail 'gestor desconocido; se requiere inspección.' ;;
  esac
  case "${1:-repair}" in
    repair)
      if [ "$patched" = 0 ]; then
        tmp="$root/lock/manage.sh"
        # Insert operator feedback ahead of the authenticated original manager.
        { head -n 1 "$root/manage.sh"; cat <<'PATCH'
if [ "${1:-}" = update ]; then
  if [ "$(id -u)" != 0 ]; then echo "Para actualizar, ejecutá: sudo nebula update VERSION" >&2; exit 1; fi
  case "${2:-}" in 0.2.0|0.2.1) ;; *) echo "Versión desconocida. Disponibles: 0.2.0 y 0.2.1." >&2; exit 2 ;; esac
  if [ "$(readlink /Library/NebulaConnectLab/active)" = /Library/NebulaConnectLab/0.2.1/nebula ] && [ "$2" = 0.2.0 ]; then echo "No se permite volver a una versión anterior." >&2; exit 2; fi
fi
PATCH
          tail -n +2 "$root/manage.sh"
          echo 'if [ "$1" = update ]; then echo "Nebula Connect actualizado a $2."; fi'
        } > "$tmp"
        case "$(digest "$tmp")" in 800a880844c4af30b51bc2d2ea2632cf9ea278cd68cfb7ea0e037d122d4b6bf3|bea5c10d4450c5a3d55159a142805ca6e1fb029cb1bf59b024adf0432a2c994d) ;; *) rm "$tmp"; fail 'falló la verificación.' ;; esac
        chmod 755 "$tmp"; mv -f "$tmp" "$root/manage.sh"
      fi
      echo 'Mensajes del actualizador habilitados.'
      ;;
    uninstall)
      # Enumerate only the two known package inventories before deleting anything.
      for item in "$root"/* "$root"/.[!.]* "$root"/..?*; do
        [ -e "$item" ] || [ -L "$item" ] || continue
        case "$item" in "$root"/active|"$root"/base|"$root"/manage.sh|"$root"/lock) ;;
          "$root"/0.2.[01])
            [ -d "$item" ] && [ ! -L "$item" ] || fail 'directorio inesperado.'
            for f in "$item"/* "$item"/.[!.]* "$item"/..?*; do
              [ -e "$f" ] || [ -L "$f" ] || continue
              [ -f "$f" ] && [ ! -L "$f" ] || fail 'archivo inesperado.'
              case "${f##*/}" in nebula|node|NODE-LICENSE.txt|keychain-helper|manifest.json|uface-sync-worker.mjs|uface-sync-protocol.mjs|uface-photo-protocol.mjs|uface-sync-inspect.mjs|uface-sync-install.mjs) ;; *) fail 'contenido ajeno en la instalación.' ;; esac
            done ;;
          *) fail 'contenido ajeno en la instalación.' ;;
        esac
      done
      rm "$bin"
      for v in 0.2.0 0.2.1; do if [ -d "$root/$v" ]; then rm "$root/$v"/*; rmdir "$root/$v"; fi; done
      rm "$root/active" "$root/base" "$root/manage.sh"
      rmdir "$root/lock" "$root"; trap - EXIT
      echo 'Nebula Connect de laboratorio desinstalado.'
      ;;
    *) fail 'operación desconocida.' ;;
  esac
}
main "$@"
