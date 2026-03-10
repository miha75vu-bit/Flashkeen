#!/bin/sh

set -e

OPKG_BIN="$(command -v opkg || true)"

if [ -z "$OPKG_BIN" ]; then
  echo "opkg не найден. Запустите установку в среде Entware."
  exit 1
fi

$OPKG_BIN update
$OPKG_BIN install curl

mkdir -p /opt/bin

curl -L -s "https://github.com/miha75vu-bit/Flashkeen/releases/download/keenetic%2Cnetcraze%2Ckeensnap/flashkeen.sh" -o /opt/bin/flashkeen
chmod +x /opt/bin/flashkeen

echo "Flashkeen установлен. Запускайте командой: flashkeen"
