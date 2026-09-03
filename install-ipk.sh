#!/bin/sh
# Офлайн IPK Flashkeen с GitHub Releases.
# Запуск только целиком: curl -fsSL .../install-ipk.sh | sh
# Не вставляйте этот файл построчно в SSH.
set -e

REPO="miha75vu-bit/Flashkeen"

if ! command -v opkg >/dev/null 2>&1; then
  echo "opkg не найден. Запустите в среде Entware."
  exit 1
fi

command -v curl >/dev/null 2>&1 || opkg install curl || {
  opkg update 2>/dev/null || true
  opkg install curl || exit 1
}

arch=$(opkg print-architecture 2>/dev/null | grep -oE 'mips-3|mipsel-3|aarch64-3' | head -n 1)
case "$arch" in
  mips-3) ca="mips-3.4" ;;
  mipsel-3) ca="mipsel-3.4" ;;
  aarch64-3) ca="aarch64-3.10" ;;
  *)
    echo "Не удалось определить архитектуру Entware для IPK."
    exit 1
    ;;
esac

echo "=== Офлайн IPK Flashkeen (не online install.sh) ==="
json=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest") || exit 1
tag=$(printf '%s' "$json" | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -n 1)
ver=$(printf '%s' "$tag" | sed 's/^[Ff]lashkeen//;s/^v//')
[ -n "$ver" ] || { echo "Не удалось прочитать версию релиза."; exit 1; }

f="flashkeen_${ver}_${ca}.ipk"
tmp="/tmp/$f"
url="https://github.com/$REPO/releases/download/${tag}/$f"

echo "Скачиваю $f ..."
curl -fL -o "$tmp" "$url" || {
  u="https://github.com/$REPO/releases/download/Flashkeen${ver}/$f"
  curl -fL -o "$tmp" "$u" || exit 1
}

if command -v gzip >/dev/null 2>&1 && gzip -t "$tmp" 2>/dev/null; then
  :
else
  m=$(od -An -tx1 -N 2 "$tmp" 2>/dev/null | tr -d ' \n')
  case "$m" in
    1f8b) ;;
    *)
      echo "Ошибка: $tmp не похож на IPK Entware (gzip)."
      exit 1
      ;;
  esac
fi

export FLASHKEEN_INSTALLED_IPK_PATH="$tmp"
rm -f /opt/tmp/opkg.lock
opkg remove flashkeen-installer >/dev/null 2>&1 || true
opkg list-installed 2>/dev/null | grep -q '^flashkeen ' && opkg remove flashkeen >/dev/null 2>&1 || true

echo "Устанавливаю $f ..."
opkg install "$tmp" || opkg install --force-reinstall "$tmp"

[ -x /opt/bin/flashkeen ] && /opt/bin/flashkeen --write-flash-wrapper 2>/dev/null || true
echo "Flashkeen (офлайн IPK) установлен."
exec /opt/bin/flash 2>/dev/null || exec /opt/bin/flashkeen
