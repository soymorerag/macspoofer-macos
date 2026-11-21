#!/usr/bin/env bash
# MAC Spoofer CLI para macOS (equivalente a TMAC)
# Uso:
#   ./macspoofer.sh list
#   ./macspoofer.sh change <iface> [mac|random]
#   ./macspoofer.sh restore <iface>
set -euo pipefail

DATA_DIR="$HOME/Library/Application Support/MACSpoofer"
mkdir -p "$DATA_DIR"

list_ifaces() {
  /usr/sbin/networksetup -listallhardwareports | awk '
    /^Hardware Port:/ { name=substr($0, index($0,":")+2) }
    /^Device:/ { dev=$2; print name "  [" dev "]" }
  '
}

is_wifi() {
  /usr/sbin/networksetup -getairportpower "$1" >/dev/null 2>&1
}

apply_mac() {
  local dev="$1" mac="$2"
  if is_wifi "$dev"; then
    sudo /usr/sbin/networksetup -setairportpower "$dev" off
    sudo /usr/sbin/networksetup -setairportpower "$dev" on
    sudo /sbin/ifconfig "$dev" ether "$mac"
  else
    sudo /sbin/ifconfig "$dev" down
    sudo /sbin/ifconfig "$dev" ether "$mac"
    sudo /sbin/ifconfig "$dev" up
  fi
  sleep 1
  local applied
  applied=$(/sbin/ifconfig "$dev" | awk '/ether/{print $2; exit}')
  if [ "$applied" = "$mac" ]; then
    echo "OK: $dev -> $applied"
  else
    echo "FAIL: $dev reporta $applied (esperado $mac)" >&2
    return 1
  fi
}

cmd="${1:-list}"
case "$cmd" in
  list)
    list_ifaces
    echo
    for line in $(list_ifaces | sed -n 's/.*\[\(.*\)\].*/\1/p'); do
      echo "$line: $(/sbin/ifconfig "$line" | awk '/ether/{print $2; exit}')"
    done
    ;;
  change)
    dev="${2:?falta interfaz, ej. en0}"
    spec="${3:-random}"
    if [ "$spec" = "random" ]; then
      mac="02:$(/usr/bin/openssl rand -hex 5 | /usr/bin/sed 's/../&:/g; s/:$//')"
    else
      mac="$spec"
    fi
    # guardar original si no existe
    origfile="$DATA_DIR/$dev.mac"
    if [ ! -f "$origfile" ]; then
      /sbin/ifconfig "$dev" | awk '/ether/{print $2; exit}' > "$origfile"
    fi
    apply_mac "$dev" "$mac"
    ;;
  restore)
    dev="${2:?falta interfaz, ej. en0}"
    origfile="$DATA_DIR/$dev.mac"
    if [ -f "$origfile" ]; then
      mac=$(cat "$origfile")
    else
      echo "No hay MAC original guardada para $dev" >&2
      exit 1
    fi
    apply_mac "$dev" "$mac"
    ;;
  *)
    echo "Uso: $0 {list|change <iface> [mac|random]|restore <iface>}" >&2
    exit 1
    ;;
esac
