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

REPO="miha75vu-bit/Flashkeen"
RELEASES_API_URL="https://api.github.com/repos/$REPO/releases?per_page=20"
DEFAULT_ASSET_URL="https://github.com/$REPO/releases/latest/download/flashkeen"

extract_num_ver() {
  # Извлекает первую подпоследовательность вида 1 или 1.2.3
  printf "%s" "$1" | sed -n 's/[^0-9]*\([0-9][0-9.]*\).*/\1/p'
}

stable_tag=""
stable_label=""
test_tag=""
test_label=""

echo "Проверяю доступные версии Flashkeen..."
releases_json="$(curl -fsL --connect-timeout 2 --max-time 8 "$RELEASES_API_URL" 2>/dev/null || true)"

if [ -n "$releases_json" ]; then
  rel_lines="$(printf "%s" "$releases_json" | sed 's/},{/}\n{/g')"
  OLD_IFS="$IFS"
  IFS='
'
  for rel_obj in $rel_lines; do
    rel_tag="$(printf "%s\n" "$rel_obj" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | awk 'NR==1{print; exit}')"
    rel_name="$(printf "%s\n" "$rel_obj" | sed -n 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/p' | awk 'NR==1{print; exit}')"
    [ -n "$rel_tag" ] || continue

    combo_lc="$(printf "%s %s" "$rel_tag" "$rel_name" | tr '[:upper:]' '[:lower:]')"
    ver="$(extract_num_ver "$rel_name")"
    [ -n "$ver" ] || ver="$(extract_num_ver "$rel_tag")"
    label="$rel_name"
    [ -n "$label" ] || label="$rel_tag"

    case "$combo_lc" in
      *test*)
        if [ -z "$test_tag" ]; then
          test_tag="$rel_tag"
          test_label="$label"
        fi
        ;;
      *)
        if [ -z "$stable_tag" ] && [ -n "$ver" ]; then
          stable_tag="$rel_tag"
          stable_label="$ver"
        fi
        ;;
    esac

    [ -n "$stable_tag" ] && [ -n "$test_tag" ] && break
  done
  IFS="$OLD_IFS"
fi

chosen_tag=""
chosen_label=""
chosen_url=""

if [ -n "$test_tag" ] && [ -n "$stable_tag" ] && [ -t 0 ]; then
  echo
  echo "Доступны версии Flashkeen:"
  echo "1) Стабильная: $stable_label"
  echo "2) Тестовая:   $test_label"
  echo "0) Отмена"
  echo -n "Ваш выбор (по умолчанию 1): "
  read install_choice
  [ "$install_choice" = "00" ] && exit 0
  [ -z "$install_choice" ] && install_choice="1"
  case "$install_choice" in
    2)
      chosen_tag="$test_tag"
      chosen_label="$test_label"
      ;;
    0)
      echo "Установка отменена."
      exit 0
      ;;
    *)
      chosen_tag="$stable_tag"
      chosen_label="$stable_label"
      ;;
  esac
elif [ -n "$test_tag" ] && [ -t 0 ]; then
  echo
  echo "Найдена только тестовая версия: $test_label"
  echo "1) Установить тестовую версию"
  echo "0) Отмена"
  echo -n "Ваш выбор (по умолчанию 1): "
  read install_choice
  [ "$install_choice" = "00" ] && exit 0
  [ -z "$install_choice" ] && install_choice="1"
  case "$install_choice" in
    0)
      echo "Установка отменена."
      exit 0
      ;;
    *)
      chosen_tag="$test_tag"
      chosen_label="$test_label"
      ;;
  esac
elif [ -n "$stable_tag" ]; then
  chosen_tag="$stable_tag"
  chosen_label="$stable_label"
fi

if [ -n "$chosen_tag" ]; then
  chosen_url="https://github.com/$REPO/releases/download/$chosen_tag/flashkeen"
else
  chosen_url="$DEFAULT_ASSET_URL"
  chosen_label="latest"
fi

echo
echo "Скачиваю Flashkeen: $chosen_label"
curl -fL -s "$chosen_url" -o /opt/bin/flashkeen

chmod +x /opt/bin/flashkeen

# Алиасы для удобного запуска
ln -sf /opt/bin/flashkeen /opt/bin/Flashkeen
ln -sf /opt/bin/flashkeen /opt/bin/flash

installed_ver="$(awk -F'"' '/^FLASHKEEN_VERSION=/{print $2; exit}' /opt/bin/flashkeen 2>/dev/null)"
[ -n "$installed_ver" ] || installed_ver="не удалось определить"

echo "Flashkeen установлен."
echo "Установленная версия: $installed_ver"
if printf "%s" "$chosen_label" | tr '[:upper:]' '[:lower:]' | awk '/test/{ok=1} END{exit ok?0:1}'; then
  echo "Тип сборки: test ($chosen_label)"
else
  echo "Тип сборки: стабильная"
fi
echo "Запуск: flashkeen  или  Flashkeen  или  flash"
