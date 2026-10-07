#!/bin/sh
# Установка webui-speed с GitHub: скин (Alternative WebUI) + демон fk-sysinfo.
#
# Использование (на роутере / Entware):
#   FK_WEBUI_REPO=USER/REPO sh install-from-github.sh
#   FK_WEBUI_REPO=USER/REPO FK_WEBUI_TAG=v1.1.0 sh install-from-github.sh
#
# Переменные:
#   FK_WEBUI_REPO   — обязателен: owner/name репозитория на GitHub
#   FK_WEBUI_TAG    — тег релиза или latest (по умолчанию latest)
#   FK_WEBUI_ASSET  — имя zip в релизе (по умолчанию ищем webui-speed*.zip)
#   FK_WEBUI_ROOT   — куда ставить (по умолчанию /opt/etc/qBittorrent_entware/webui-speed)
#   FK_WEBUI_SKIP_DAEMON=1 — только скин, без демона
#
set -e

REPO="${FK_WEBUI_REPO:-}"
TAG="${FK_WEBUI_TAG:-latest}"
DEST="${FK_WEBUI_ROOT:-/opt/etc/qBittorrent_entware/webui-speed}"
ASSET_HINT="${FK_WEBUI_ASSET:-}"
TMP="/tmp/webui-speed-install.$$"
INIT_D="/opt/etc/init.d/S90fk-sysinfo"

die() { echo "Ошибка: $*" >&2; exit 1; }

[ -n "$REPO" ] || die "Задайте FK_WEBUI_REPO=owner/name (репозиторий на GitHub)"

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Нужна команда: $1"
}

fetch() {
    # fetch URL OUT
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1" || return 1
    else
        die "Нужен curl или wget"
    fi
}

echo "=== webui-speed: установка с GitHub ==="
echo "Репозиторий: $REPO"
echo "Каталог:     $DEST"

rm -rf "$TMP"
mkdir -p "$TMP"

# --- скачать архив ---
ZIP="$TMP/webui-speed.zip"
if [ "$TAG" = "latest" ]; then
    API="https://api.github.com/repos/$REPO/releases/latest"
    echo "Читаю latest release…"
    fetch "$API" "$TMP/release.json" || die "Не удалось получить $API"
    # предпочитаем asset webui-speed*.zip
    if [ -n "$ASSET_HINT" ]; then
        URL=$(sed -n "s/.*\"browser_download_url\": \"\\([^\"]*${ASSET_HINT}[^\"]*\\)\".*/\\1/p" "$TMP/release.json" | head -n 1)
    else
        URL=$(sed -n 's/.*"browser_download_url": "\([^"]*webui-speed[^"]*\.zip\)".*/\1/p' "$TMP/release.json" | head -n 1)
        [ -n "$URL" ] || URL=$(sed -n 's/.*"browser_download_url": "\([^"]*\.zip\)".*/\1/p' "$TMP/release.json" | head -n 1)
    fi
    TAG_NAME=$(sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' "$TMP/release.json" | head -n 1)
    [ -n "$URL" ] || {
        # fallback: source zipball
        [ -n "$TAG_NAME" ] || die "Нет tag_name в ответе API"
        URL="https://github.com/$REPO/archive/refs/tags/${TAG_NAME}.zip"
        echo "В релизе нет .zip asset — беру source: $TAG_NAME"
    }
    echo "Тег: $TAG_NAME"
else
    # явный тег: сначала asset, иначе zipball
    API="https://api.github.com/repos/$REPO/releases/tags/$TAG"
    if fetch "$API" "$TMP/release.json" 2>/dev/null; then
        if [ -n "$ASSET_HINT" ]; then
            URL=$(sed -n "s/.*\"browser_download_url\": \"\\([^\"]*${ASSET_HINT}[^\"]*\\)\".*/\\1/p" "$TMP/release.json" | head -n 1)
        else
            URL=$(sed -n 's/.*"browser_download_url": "\([^"]*webui-speed[^"]*\.zip\)".*/\1/p' "$TMP/release.json" | head -n 1)
            [ -n "$URL" ] || URL=$(sed -n 's/.*"browser_download_url": "\([^"]*\.zip\)".*/\1/p' "$TMP/release.json" | head -n 1)
        fi
    fi
    [ -n "$URL" ] || URL="https://github.com/$REPO/archive/refs/tags/${TAG}.zip"
fi

echo "Скачиваю: $URL"
fetch "$URL" "$ZIP" || die "Не удалось скачать архив"

# --- распаковать ---
need_cmd unzip
unzip -q -o "$ZIP" -d "$TMP/extract" || die "unzip не удался"
# найти корень с private/index.html
SRC=""
for d in "$TMP/extract" "$TMP/extract"/*; do
    [ -d "$d" ] || continue
    if [ -f "$d/private/index.html" ] && [ -f "$d/public/index.html" ]; then
        SRC="$d"
        break
    fi
done
[ -n "$SRC" ] || die "В архиве нет private/ и public/ (ожидается корень темы webui-speed)"

echo "Источник: $SRC"

# --- скин ---
mkdir -p "$DEST"
# runtime JSON/маяки/историю не трогаем при обновлении
rm -rf "$DEST/private" "$DEST/public" "$DEST/translations"
cp -a "$SRC/private" "$DEST/private"
cp -a "$SRC/public" "$DEST/public"
if [ -d "$SRC/translations" ]; then
    cp -a "$SRC/translations" "$DEST/translations"
fi
cp "$SRC/version.txt" "$DEST/version.txt" 2>/dev/null || printf '%s\n' "webui-speed" > "$DEST/version.txt"
cp "$SRC/README.md" "$DEST/README.md" 2>/dev/null || true
cp "$SRC/install.sh" "$DEST/install.sh" 2>/dev/null || true
cp "$SRC/install-from-github.sh" "$DEST/install-from-github.sh" 2>/dev/null || true

if [ -d "$SRC/daemon" ]; then
    rm -rf "$DEST/daemon"
    cp -a "$SRC/daemon" "$DEST/daemon"
    chmod +x "$DEST/daemon/fk-sysinfo-loop.sh" "$DEST/daemon/S90fk-sysinfo" "$DEST/daemon/install.sh" 2>/dev/null || true
fi
mkdir -p "$DEST/private/fk-want" 2>/dev/null || true
chmod -R a+rX "$DEST" 2>/dev/null || true
chmod +x "$DEST/install.sh" "$DEST/install-from-github.sh" 2>/dev/null || true

# --- qBittorrent.conf ---
CONF=""
for c in \
    /opt/etc/qBittorrent_entware/config/qBittorrent.conf \
    /opt/etc/qBittorrent/config/qBittorrent.conf \
    /opt/root/.config/qBittorrent/qBittorrent.conf \
    "$HOME/.config/qBittorrent/qBittorrent.conf"
do
    [ -f "$c" ] && CONF="$c" && break
done

if [ -n "$CONF" ]; then
    if grep -q '^WebUI\\AlternativeUIEnabled=' "$CONF" 2>/dev/null; then
        sed -i 's|^WebUI\\AlternativeUIEnabled=.*|WebUI\\AlternativeUIEnabled=true|' "$CONF"
    else
        printf '%s\n' 'WebUI\AlternativeUIEnabled=true' >> "$CONF"
    fi
    if grep -q '^WebUI\\RootFolder=' "$CONF" 2>/dev/null; then
        sed -i "s|^WebUI\\\\RootFolder=.*|WebUI\\\\RootFolder=$DEST|" "$CONF"
    else
        printf '%s\n' "WebUI\\RootFolder=$DEST" >> "$CONF"
    fi
    echo "qBittorrent.conf: AlternativeUI → $DEST"
else
    echo "Конфиг qBittorrent не найден — укажите вручную:"
    echo "  WebUI → Use alternative WebUI → папка: $DEST"
fi

# --- демон ---
if [ "${FK_WEBUI_SKIP_DAEMON:-0}" = "1" ]; then
    echo "Демон пропущен (FK_WEBUI_SKIP_DAEMON=1)."
elif [ ! -f "$DEST/daemon/fk-sysinfo-loop.sh" ]; then
    echo "В архиве нет daemon/ — метрики CPU/RAM хоста не будут доступны."
else
    export FK_WEBUI_ROOT="$DEST"
    sed "s|^THEME_ROOT=.*|THEME_ROOT=\"$DEST\"|" "$DEST/daemon/S90fk-sysinfo" > "$INIT_D"
    chmod +x "$INIT_D" "$DEST/daemon/fk-sysinfo-loop.sh"
    "$INIT_D" stop 2>/dev/null || true
    FK_WEBUI_ROOT="$DEST" "$INIT_D" start
    echo "Демон fk-sysinfo запущен → $DEST/private/fk-sysinfo.json"
fi

rm -rf "$TMP"
echo ""
echo "Готово. Обновите WebUI: Ctrl+F5"
echo "Скин:  $DEST"
[ "${FK_WEBUI_SKIP_DAEMON:-0}" = "1" ] || echo "Демон: $INIT_D"
