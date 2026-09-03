#!/bin/sh
set -e

REPO="miha75vu-bit/Flashkeen"
# /releases/latest — только стабильный (не prerelease).
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

# JSON /releases/latest: имя релиза и id ассета flashkeen.
latest_json=$(curl -fsL --connect-timeout 8 --max-time 25 "$LATEST_API_URL" 2>/dev/null || true)

chosen_label=$(printf '%s' "$latest_json" | awk '
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

# id ассета: ближайший "id" слева от "name":"flashkeen"
asset_id=$(printf '%s' "$latest_json" | awk '
  { doc = doc $0 }
  END {
    pos = 1
    while (1) {
      p = index(substr(doc, pos), "\"name\"")
      if (p == 0) break
      pos = pos + p - 1
      rest = substr(doc, pos)
      if (match(rest, /"name"[[:space:]]*:[[:space:]]*"flashkeen"/) == 0) {
        pos = pos + 6
        next
      }
      start = pos - 250
      if (start < 1) start = 1
      chunk = substr(doc, start, pos - start)
      idpart = ""
      while (match(chunk, /"id"[[:space:]]*:[[:space:]]*[0-9]+/)) {
        idpart = substr(chunk, RSTART, RLENGTH)
        chunk = substr(chunk, RSTART + RLENGTH)
      }
      gsub(/[^0-9]/, "", idpart)
      if (idpart != "") { print idpart; exit }
      pos = pos + 6
    }
  }
')

flashkeen_download_ok() {
  [ -s /opt/bin/flashkeen ] || return 1
  case "$(head -n 1 /opt/bin/flashkeen 2>/dev/null)" in
    '#!/'*) return 0 ;;
  esac
  return 1
}

echo "Проверяю последнюю версию Flashkeen..."
echo "Скачиваю Flashkeen: $chosen_label"

dl_ok=0
rm -f /opt/bin/flashkeen 2>/dev/null || true

# 1) Через api.github.com (часто доступен, когда github.com/CDN — нет).
if [ -n "$asset_id" ]; then
  case "$asset_id" in
    *[!0-9]*) ;;
    *)
      api_url="https://api.github.com/repos/$REPO/releases/assets/$asset_id"
      if curl -fL -s --connect-timeout 10 --max-time 180 \
          -H "Accept: application/octet-stream" \
          -H "User-Agent: flashkeen-install" \
          "$api_url" -o /opt/bin/flashkeen \
        && flashkeen_download_ok; then
        dl_ok=1
      else
        rm -f /opt/bin/flashkeen 2>/dev/null || true
      fi
      ;;
  esac
fi

# 2) Фолбэк: releases/latest/download (github.com → CDN).
if [ "$dl_ok" != "1" ]; then
  set +e
  curl -fL -s --connect-timeout 10 --max-time 180 "$LATEST_ASSET_URL" -o /opt/bin/flashkeen
  _curl_rc=$?
  set -e
  if [ "$_curl_rc" -eq 0 ] && flashkeen_download_ok; then
    dl_ok=1
  else
    rm -f /opt/bin/flashkeen 2>/dev/null || true
    echo "Не удалось скачать Flashkeen (curl код ${_curl_rc:-?})."
    [ -n "$asset_id" ] && echo "Пробовали API asset id: $asset_id"
    echo "Пробовали URL: $LATEST_ASSET_URL"
    echo "api.github.com отвечает, скачивание с github.com/CDN на этом роутере часто падает."
    exit 1
  fi
fi

chmod +x /opt/bin/flashkeen

ln -sf /opt/bin/flashkeen /opt/bin/Flashkeen
printf '%s\n' '#!/bin/sh' '/opt/bin/flashkeen "$@"' 'exit $?' > /opt/bin/flash
chmod +x /opt/bin/flash 2>/dev/null || true

echo "Установка базовых пакетов Entware..."
/opt/bin/flashkeen --install-core-packages || true

echo "Flashkeen установлен."
echo "Запуск: flashkeen  или  Flashkeen  или  flash"
