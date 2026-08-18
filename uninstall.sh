#!/bin/sh
set -e

echo "Uninstall: Flashkeen"
echo
echo "ВНИМАНИЕ: если Flashkeen сейчас запущен/что-то делает, лучше остановить его вручную."

remove_if_exists() {
  # $1: path
  rm -f "$1" 2>/dev/null || true
}

rm_rf_if_exists() {
  # $1: dir
  rm -rf "$1" 2>/dev/null || true
}

echo "Удаляю Flashkeen из /opt/bin (бинари/алиасы)..."
rm -f \
  /opt/bin/flashkeen \
  /opt/bin/Flashkeen \
  /opt/bin/flash \
  /opt/bin/update \
  /opt/bin/flashkeen.sh

rm -f \
  /tmp/flashkeen-install.sh \
  /tmp/flashkeen-uninstall.sh

echo "Удаляю служебные файлы проверки обновлений..."
rm -f \
  /opt/var/lib/flashkeen/skip_update_prompt_for_version \
  /opt/var/lib/flashkeen/latest_release_cache

# Следы, которые использует сам flashkeen (state/lock/stage/cache).
echo "Удаляю state/lock/стадии Flashkeen..."
rm -f \
  /opt/var/lib/flashkeen/entware_bootstrap_stamp \
  /opt/var/lib/flashkeen/active_stage.state \
  /opt/var/lib/flashkeen/instance.lock \
  /opt/var/lib/flashkeen/console_tail.lock \
  /opt/var/lib/flashkeen/session_resize_check_seen.flag \
  /opt/var/lib/flashkeen/keenkit_backup_dir

rm_rf_if_exists /opt/var/lib/flashkeen/fsck_today
rm_rf_if_exists /opt/var/lib/flashkeen/op_state

# marker used by release-selector
rm -f \
  /opt/var/lib/flashkeen/F \
  /tmp/flashkeen/F

# В flashkeen при неудаче создания state-dir иногда используется /tmp/flashkeen.
echo "Удаляю временные файлы Flashkeen из /tmp..."
rm_rf_if_exists /tmp/flashkeen

rm -rf /tmp/flashkeen.op_state 2>/dev/null || true
rm -f /tmp/flashkeen* 2>/dev/null || true

# (Optional) remove potential marker in /opt/bin
rm -f /opt/bin/F 2>/dev/null || true

echo
echo "Подчищаю алиасы flash/update в профилях..."

remove_alias_in_profile_file() {
  profile_file="$1"
  alias_name="$2"
  [ -f "$profile_file" ] || return 0
  [ -n "$alias_name" ] || return 1

  tmp_file="/tmp/uninstall-flashkeen.profile.rm.$$.$alias_name"
  awk -v alias_name="$alias_name" '
    {
      if ($0 ~ ("^alias " alias_name "=")) next
      print
    }
  ' "$profile_file" > "$tmp_file" 2>/dev/null || {
    rm -f "$tmp_file" 2>/dev/null || true
    return 1
  }
  mv "$tmp_file" "$profile_file" 2>/dev/null || {
    rm -f "$tmp_file" 2>/dev/null || true
    return 1
  }
}

for pf in /opt/etc/profile /root/.profile /opt/root/.profile; do
  remove_alias_in_profile_file "$pf" "flash" || true
  remove_alias_in_profile_file "$pf" "update" || true
  # legacy alias cleanup
  remove_alias_in_profile_file "$pf" "flashx" || true
done

echo
echo "Flashkeen удалён."
echo

if command -v opkg >/dev/null 2>&1; then
  printf "Удалить KeenSnap? (y/N): "
  read answer || answer=""
  case "$answer" in
    y|Y|yes|YES)
      echo "Удаляю KeenSnap..."
      opkg remove keensnap || true
      rm -f /opt/etc/opkg/keensnap.conf 2>/dev/null || true
      ;;
    *)
      echo "KeenSnap не трогаю."
      ;;
  esac
else
  echo "opkg не найден, KeenSnap не удаляю."
fi

flashkeen_uninstall_keenkit_version_from_script() {
  script_path="$1"
  [ -f "$script_path" ] || return 0
  grep -m1 '^SCRIPT_VERSION=' "$script_path" 2>/dev/null \
    | sed 's/^SCRIPT_VERSION="\?\([^"]*\)"\?/\1/' \
    | tr -d '\015'
}

flashkeen_uninstall_keenkit_describe_path() {
  item_path="$1"
  [ -n "$item_path" ] || return 0
  if [ -L "$item_path" ]; then
    link_target=$(readlink "$item_path" 2>/dev/null || true)
    if [ -n "$link_target" ]; then
      echo "  $item_path -> $link_target"
    else
      echo "  $item_path (ссылка)"
    fi
    return 0
  fi
  if [ -f "$item_path" ]; then
    item_version=$(flashkeen_uninstall_keenkit_version_from_script "$item_path")
    if [ -n "$item_version" ]; then
      echo "  $item_path (версия $item_version)"
    else
      echo "  $item_path"
    fi
    return 0
  fi
  echo "  $item_path (не найден)"
}

flashkeen_uninstall_keenkit_collect_hits() {
  keenkit_hits=""
  keenkit_version=""
  keenkit_script_for_version=""

  if command -v keenkit >/dev/null 2>&1; then
    keenkit_cmd=$(command -v keenkit)
    case " $keenkit_hits " in
      *" $keenkit_cmd "*) ;;
      *) keenkit_hits="$keenkit_hits $keenkit_cmd" ;;
    esac
    if [ -z "$keenkit_script_for_version" ] && [ -f "$keenkit_cmd" ]; then
      keenkit_script_for_version="$keenkit_cmd"
    fi
  fi

  for candidate in /opt/keenkit.sh /opt/bin/keenkit.sh /opt/bin/keenkit; do
    if [ -f "$candidate" ] || [ -L "$candidate" ]; then
      case " $keenkit_hits " in
        *" $candidate "*) ;;
        *) keenkit_hits="$keenkit_hits $candidate" ;;
      esac
      if [ -z "$keenkit_script_for_version" ] && [ -f "$candidate" ]; then
        keenkit_script_for_version="$candidate"
      fi
    fi
  done

  if [ -n "$keenkit_script_for_version" ]; then
    keenkit_version=$(flashkeen_uninstall_keenkit_version_from_script "$keenkit_script_for_version")
  fi

  keenkit_hits=$(printf '%s\n' "$keenkit_hits" | awk 'NF {print}' | sort -u | tr '\n' ' ')
}

flashkeen_uninstall_keenkit_remove_all() {
  rm -f /opt/bin/keenkit /opt/keenkit.sh /opt/bin/keenkit.sh 2>/dev/null || true
  rm -f /opt/var/lib/flashkeen/keenkit_backup_dir 2>/dev/null || true
}

echo
echo "Проверяю KeenKit..."
flashkeen_uninstall_keenkit_collect_hits

if [ -n "$keenkit_hits" ]; then
  echo
  echo "Найдены следы KeenKit:"
  for hit in $keenkit_hits; do
    flashkeen_uninstall_keenkit_describe_path "$hit"
  done
  if [ -n "$keenkit_version" ]; then
    echo "Версия скрипта KeenKit: $keenkit_version"
  else
    echo "Версию скрипта KeenKit определить не удалось."
  fi

  keensnap_traces=0
  if command -v opkg >/dev/null 2>&1 && opkg list-installed 2>/dev/null | grep -q '^keensnap '; then
    keensnap_traces=1
  fi
  if [ -f /opt/etc/keensnap/keensnap.conf ] || [ -f /opt/etc/keensnap.conf ] \
    || [ -f /opt/share/keensnap/keensnap.sh ] || [ -f /opt/bin/keensnap ]; then
    keensnap_traces=1
  fi
  if [ "$keensnap_traces" -eq 1 ]; then
    echo
    echo "Есть следы KeenSnap. Если бэкапы делались через KeenSnap, файлы KeenKit, скорее всего, остаток старой установки — их можно удалить."
  fi

  printf "Удалить KeenKit? (y/N): "
  read answer || answer=""
  case "$answer" in
    y|Y|yes|YES)
      echo "Удаляю KeenKit..."
      flashkeen_uninstall_keenkit_remove_all
      flashkeen_uninstall_keenkit_collect_hits
      if [ -n "$keenkit_hits" ]; then
        echo "KeenKit удалить не удалось полностью. Осталось:"
        for hit in $keenkit_hits; do
          flashkeen_uninstall_keenkit_describe_path "$hit"
        done
      else
        echo "KeenKit удалён."
      fi
      ;;
    *)
      echo "KeenKit не трогаю."
      ;;
  esac
else
  echo "KeenKit не найден."
fi

echo "Готово."
