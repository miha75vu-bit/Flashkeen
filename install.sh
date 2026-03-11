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

echo "Скачиваю Flashkeen..."
curl -L -s "https://github.com/miha75vu-bit/Flashkeen/releases/download/Flashkeen/flashkeen" \
  -o /opt/bin/flashkeen

chmod +x /opt/bin/flashkeen

# Алиасы для удобного запуска
ln -sf /opt/bin/flashkeen /opt/bin/Flashkeen
ln -sf /opt/bin/flashkeen /opt/bin/flash

echo "Flashkeen установлен."
echo "Запуск: flashkeen  или  Flashkeen  или  flash"
