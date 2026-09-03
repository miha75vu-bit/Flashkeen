#!/bin/sh
set -e

REPO="miha75vu-bit/Flashkeen"
RELEASES_API_URL="https://api.github.com/repos/$REPO/releases?per_page=10"
DEFAULT_ASSET_URL="https://github.com/$REPO/releases/latest/download/flashkeen"
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

# tag<TAB>name<TAB>prerelease по каждому релизу, новые сначала.
# Значения читаются с учётом кавычек и экранирования, поэтому запятые в названиях не ломают разбор.
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

split_row() {
  row="$1"
  ROW_TAG=${row%%"$TAB"*}
  row_rest=${row#*"$TAB"}
  ROW_NAME=${row_rest%%"$TAB"*}
  ROW_PRE=${row_rest#*"$TAB"}
  [ "$ROW_TAG" != "$row" ] || { ROW_NAME=""; ROW_PRE="false"; }
  [ -n "$ROW_NAME" ] || ROW_NAME="$ROW_TAG"
}

chosen_url="$DEFAULT_ASSET_URL"
chosen_label="latest release"

echo "Проверяю последнюю версию Flashkeen..."
releases="$(github_releases_tsv "$RELEASES_API_URL" || true)"

# Ищем первый стабильный релиз (prerelease=false, без маркера test).
stable_row="$(printf "%s\n" "$releases" | awk -F"$TAB" '
  function has_test(s) { return (" " tolower(s)) ~ /[^a-z]test/ }
  $1 != "" && $3 != "true" && !has_test($1) && !has_test($2) { print; exit }
')"
if [ -n "$stable_row" ]; then
  split_row "$stable_row"
  chosen_url="https://github.com/$REPO/releases/download/$ROW_TAG/flashkeen"
  chosen_label="$ROW_NAME"
fi

echo "Скачиваю Flashkeen: $chosen_label"
curl -fL -s "$chosen_url" -o /opt/bin/flashkeen

[ -s /opt/bin/flashkeen ] || {
  echo "Не удалось скачать Flashkeen."
  rm -f /opt/bin/flashkeen 2>/dev/null
  exit 1
}

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
