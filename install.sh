#!/bin/sh
set -e

REPO="miha75vu-bit/Flashkeen"
# GitHub /releases/latest никогда не указывает на prerelease.
LATEST_API_URL="https://api.github.com/repos/$REPO/releases/latest"
LATEST_ASSET_URL="https://github.com/$REPO/releases/latest/download/flashkeen"

OPKG_BIN="$(command -v opkg || true)"
if [ -z "$OPKG_BIN" ]; then
  echo "opkg не найден. Запустите установку в среде Entware."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  "$OPKG_BIN" update || true
  "$OPKG_BIN" install curl || {
    echo "Не удалось установить curl."
    exit 1
  }
fi

mkdir -p /opt/bin

# Имя стабильного релиза из /releases/latest (без списка, без prerelease).
chosen_label=$(curl -fsL --connect-timeout 5 --max-time 20 "$LATEST_API_URL" 2>/dev/null | awk '
  {
    p = index($0, "\"name\":")
    if (p == 0) next
    rest = substr($0, p + 7)
    if (match(rest, /^[ \t]*"/)) {
      rest = substr(rest, RLENGTH + 1)
      out = ""
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (c == "\\") { out = out substr(rest, i + 1, 1); i++; continue }
        if (c == "\"") break
        out = out c
      }
      print out
      exit
    }
  }
')
[ -n "$chosen_label" ] || chosen_label="latest release"

echo "Проверяю последнюю версию Flashkeen..."
echo "Скачиваю Flashkeen: $chosen_label"
curl -fL -s --connect-timeout 10 --max-time 180 "$LATEST_ASSET_URL" -o /opt/bin/flashkeen

[ -s /opt/bin/flashkeen ] || {
  echo "Не удалось скачать Flashkeen."
  rm -f /opt/bin/flashkeen 2>/dev/null
  exit 1
}

chmod +x /opt/bin/flashkeen

ln -sf /opt/bin/flashkeen /opt/bin/Flashkeen
printf '%s\n' '#!/bin/sh' '/opt/bin/flashkeen "$@"' 'exit $?' > /opt/bin/flash
chmod +x /opt/bin/flash 2>/dev/null || true

echo "Установка базовых пакетов Entware..."
if /opt/bin/flashkeen --install-core-packages; then
  :
else
  echo "Предупреждение: не все базовые пакеты установились."
fi

echo "Flashkeen установлен."
echo "Запуск: flashkeen  или  Flashkeen  или  flash"
