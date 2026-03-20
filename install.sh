#!/bin/sh
set -e

OPKG_BIN="$(command -v opkg || true)"
if [ -z "$OPKG_BIN" ]; then
  echo "opkg не найден. Запустите установку в среде Entware."
  exit 1
fi

# Ставим curl только если его нет
if ! command -v curl >/dev/null 2>&1; then
  "$OPKG_BIN" update
  "$OPKG_BIN" install curl
fi

mkdir -p /opt/bin

echo "Скачиваю Flashkeen (latest release)..."
curl -fL -s "https://github.com/miha75vu-bit/Flashkeen/releases/latest/download/flashkeen" \
  -o /opt/bin/flashkeen

chmod +x /opt/bin/flashkeen

# Алиасы для удобного запуска
ln -sf /opt/bin/flashkeen /opt/bin/Flashkeen
ln -sf /opt/bin/flashkeen /opt/bin/flash

echo "Flashkeen установлен."
echo "Запуск: flashkeen  или  Flashkeen  или  flash"
