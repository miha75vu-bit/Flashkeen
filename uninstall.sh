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
  /opt/var/lib/flashkeen/session_resize_check_seen.flag

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

echo "Готово."

echo
echo "Проверяю KeenKit..."
keenkit_found=0
if command -v keenkit >/dev/null 2>&1; then
  keenkit_found=1
fi
if [ -x /opt/keenkit.sh ]; then
  keenkit_found=1
fi

if [ "$keenkit_found" -eq 1 ]; then
  echo
  echo "KeenKit установлен."
  echo "К сожалению, его автор не сделал доступной функцию удаления — возможно, она появится в дальнейшем."
  echo "Справка: https://keeneticported.dev/wiki/helpful/keenkit"
fi

