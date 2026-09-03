#!/bin/sh
set -e

REPO="miha75vu-bit/Flashkeen"
RELEASES_API_URL="https://api.github.com/repos/$REPO/releases?per_page=10"
DEFAULT_ASSET_URL="https://github.com/$REPO/releases/latest/download/flashkeen"
GITHUB_HOST_IP="185.199.109.133"
TAB=$(printf '\t')

OPKG_BIN="$(command -v opkg || true)"
if [ -z "$OPKG_BIN" ]; then
  echo "opkg не найден. Запустите установку в среде Entware."
  exit 1
fi

# Ставим curl только если его нет
if ! command -v curl >/dev/null 2>&1; then
  "$OPKG_BIN" update || true
  "$OPKG_BIN" install curl || {
    echo "Не удалось установить curl."
    exit 1
  }
fi

mkdir -p /opt/bin

# Keenetic: ndmc часто падает. Hosts — через RCI (на случай фолбэка через github.com).
install_rci_parse() {
  curl -fsS --connect-timeout 3 --max-time 8 \
    -H "Content-Type: application/json" \
    -d "[{\"parse\":\"$1\"}]" \
    "http://localhost:79/rci/" >/dev/null 2>&1
}

install_apply_github_hosts() {
  for cmd in \
    "ip host github.com $GITHUB_HOST_IP" \
    "ip host raw.githubusercontent.com $GITHUB_HOST_IP" \
    "ip host release-assets.githubusercontent.com $GITHUB_HOST_IP" \
    "system configuration save"
  do
    install_rci_parse "$cmd" || true
  done
}

# tag<TAB>name<TAB>prerelease по каждому релизу, новые сначала.
github_releases_tsv() {
  curl -fsL --connect-timeout 5 --max-time 20 "$1" 2>/dev/null | awk '
    function jstr(s, start,   i, c, out) {
        i = start + 1
        out = ""
        while (i <= length(s)) {
            c = substr(s, i, 1)
            if (c == "\\") { out = out substr(s, i + 1, 1); i += 2; continue }
            if (c == "\"") break
            out = out c
            i++
        }
        JEND = i
        return out
    }
    function field(s, pos, key,   p, rest) {
        p = index(substr(s, pos), "\"" key "\":")
        if (p == 0) return -1
        p = pos + p - 1 + length(key) + 3
        rest = substr(s, p)
        if (match(rest, /^[ \t]*"/) == 0) { JEND = p; JVAL = ""; return 0 }
        JVAL = jstr(s, p + RLENGTH - 1)
        return 1
    }
    { doc = doc $0 }
    END {
        pos = 1
        while (1) {
            if (field(doc, pos, "tag_name") == -1) break
            tag = JVAL
            pos = JEND + 1
            if (field(doc, pos, "name") == -1) break
            name = JVAL
            pos = JEND + 1
            pre = "false"
            p = index(substr(doc, pos), "\"prerelease\":")
            if (p > 0) {
                p = pos + p - 1 + 13
                if (substr(doc, p, 5) ~ /true/) pre = "true"
            }
            if (tag != "") print tag "\t" name "\t" pre
        }
    }
  '
}

# id ассета flashkeen для тега (скачивание через api.github.com, без CDN github.com).
release_asset_id_for_tag() {
  tag="$1"
  [ -n "$tag" ] || return 1
  curl -fsL --connect-timeout 5 --max-time 20 \
    "https://api.github.com/repos/$REPO/releases/tags/$tag" 2>/dev/null | awk '
    function jstr(s, start,   i, c, out) {
        i = start + 1
        out = ""
        while (i <= length(s)) {
            c = substr(s, i, 1)
            if (c == "\\") { out = out substr(s, i + 1, 1); i += 2; continue }
            if (c == "\"") break
            out = out c
            i++
        }
        JEND = i
        return out
    }
    function field(s, pos, key,   p, rest) {
        p = index(substr(s, pos), "\"" key "\":")
        if (p == 0) return -1
        p = pos + p - 1 + length(key) + 3
        rest = substr(s, p)
        if (match(rest, /^[ \t]*"/) == 0) { JEND = p; JVAL = ""; return 0 }
        JVAL = jstr(s, p + RLENGTH - 1)
        return 1
    }
    { doc = doc $0 }
    END {
        pos = 1
        while (1) {
            # Ищем блок ассета: "name":"flashkeen", рядом "id":...
            p = index(substr(doc, pos), "\"name\"")
            if (p == 0) break
            pos = pos + p - 1
            if (field(doc, pos, "name") == -1) break
            aname = JVAL
            apos = JEND + 1
            if (aname == "flashkeen") {
                # id в JSON ассета стоит перед name — берём ближайший id слева.
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
            }
            pos = apos
        }
    }
  '
}

# id ассета flashkeen у releases/latest (стабильный).
release_asset_id_latest() {
  curl -fsL --connect-timeout 5 --max-time 20 \
    "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | awk '
    function jstr(s, start,   i, c, out) {
        i = start + 1
        out = ""
        while (i <= length(s)) {
            c = substr(s, i, 1)
            if (c == "\\") { out = out substr(s, i + 1, 1); i += 2; continue }
            if (c == "\"") break
            out = out c
            i++
        }
        JEND = i
        return out
    }
    function field(s, pos, key,   p, rest) {
        p = index(substr(s, pos), "\"" key "\":")
        if (p == 0) return -1
        p = pos + p - 1 + length(key) + 3
        rest = substr(s, p)
        if (match(rest, /^[ \t]*"/) == 0) { JEND = p; JVAL = ""; return 0 }
        JVAL = jstr(s, p + RLENGTH - 1)
        return 1
    }
    { doc = doc $0 }
    END {
        pos = 1
        while (1) {
            p = index(substr(doc, pos), "\"name\"")
            if (p == 0) break
            pos = pos + p - 1
            if (field(doc, pos, "name") == -1) break
            aname = JVAL
            apos = JEND + 1
            if (aname == "flashkeen") {
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
            }
            pos = apos
        }
    }
  '
}

split_row() {
  row="$1"
  ROW_TAG=${row%%"$TAB"*}
  row_rest=${row#*"$TAB"}
  ROW_NAME=${row_rest%%"$TAB"*}
  ROW_PRE=${row_rest#*"$TAB"}
  [ "$ROW_TAG" != "$row" ] || { ROW_NAME=""; ROW_PRE="false"; }
  [ -n "$ROW_NAME" ] || ROW_NAME="$ROW_TAG"
}

flashkeen_download_ok() {
  [ -s /opt/bin/flashkeen ] || return 1
  case "$(head -n 1 /opt/bin/flashkeen 2>/dev/null)" in
    '#!/'*) return 0 ;;
  esac
  return 1
}

# Скачивание через api.github.com (тот же хост, что уже отвечает при проверке версии).
try_download_via_api_asset() {
  asset_id="$1"
  [ -n "$asset_id" ] || return 1
  case "$asset_id" in *[!0-9]*) return 1 ;; esac
  rm -f /opt/bin/flashkeen 2>/dev/null || true
  api_url="https://api.github.com/repos/$REPO/releases/assets/$asset_id"
  if curl -fL -s --connect-timeout 10 --max-time 180 \
      -H "Accept: application/octet-stream" \
      -H "User-Agent: flashkeen-install" \
      "$api_url" -o /opt/bin/flashkeen \
    && flashkeen_download_ok; then
    return 0
  fi
  rm -f /opt/bin/flashkeen 2>/dev/null || true
  return 1
}

try_download_flashkeen_url() {
  url="$1"
  [ -n "$url" ] || return 1
  rm -f /opt/bin/flashkeen 2>/dev/null || true
  if curl -fL -s --connect-timeout 10 --max-time 180 \
      --resolve "github.com:443:$GITHUB_HOST_IP" \
      --resolve "release-assets.githubusercontent.com:443:$GITHUB_HOST_IP" \
      "$url" -o /opt/bin/flashkeen \
    && flashkeen_download_ok; then
    return 0
  fi
  if curl -fL -s --connect-timeout 10 --max-time 180 "$url" -o /opt/bin/flashkeen \
    && flashkeen_download_ok; then
    return 0
  fi
  rm -f /opt/bin/flashkeen 2>/dev/null || true
  return 1
}

install_apply_github_hosts

chosen_tag=""
chosen_label="latest release"
asset_id=""
github_url="$DEFAULT_ASSET_URL"

echo "Проверяю последнюю версию Flashkeen..."
releases="$(github_releases_tsv "$RELEASES_API_URL" || true)"

# Первый стабильный релиз (prerelease=false, без маркера test).
stable_row="$(printf "%s\n" "$releases" | awk -F"$TAB" '
  function has_test(s) { return (" " tolower(s)) ~ /[^a-z]test/ }
  $1 != "" && $3 != "true" && !has_test($1) && !has_test($2) { print; exit }
')"
if [ -n "$stable_row" ]; then
  split_row "$stable_row"
  chosen_tag="$ROW_TAG"
  chosen_label="$ROW_NAME"
  github_url="https://github.com/$REPO/releases/download/$ROW_TAG/flashkeen"
  asset_id="$(release_asset_id_for_tag "$ROW_TAG" || true)"
fi

if [ -z "$asset_id" ]; then
  asset_id="$(release_asset_id_latest || true)"
fi

echo "Скачиваю Flashkeen: $chosen_label"
dl_ok=0
if [ -n "$asset_id" ] && try_download_via_api_asset "$asset_id"; then
  dl_ok=1
elif try_download_flashkeen_url "$github_url"; then
  dl_ok=1
elif [ "$github_url" != "$DEFAULT_ASSET_URL" ] && try_download_flashkeen_url "$DEFAULT_ASSET_URL"; then
  echo "Скачано через запасной URL (releases/latest)."
  dl_ok=1
fi

if [ "$dl_ok" != "1" ]; then
  echo "Не удалось скачать Flashkeen."
  [ -n "$asset_id" ] && echo "API asset id: $asset_id (api.github.com/.../assets/$asset_id)"
  echo "Пробовали URL: $github_url"
  [ "$github_url" != "$DEFAULT_ASSET_URL" ] && echo "             $DEFAULT_ASSET_URL"
  echo "api.github.com отвечает, а github.com/CDN — часто нет."
  echo "Hosts через RCI (если нужен фолбэк):"
  echo "  curl -fsS -H 'Content-Type: application/json' -d '[{\"parse\":\"ip host release-assets.githubusercontent.com $GITHUB_HOST_IP\"}]' http://localhost:79/rci/"
  exit 1
fi

chmod +x /opt/bin/flashkeen

# Точки входа до первого запуска; дальше их обслуживает сам flashkeen.
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
