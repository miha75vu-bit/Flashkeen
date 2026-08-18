#!/bin/sh

echo "Uninstall: Flashkeen"

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

opkg_remove_if_installed() {
  pkg="$1"
  opkg list-installed 2>/dev/null | grep -q "^${pkg} " || return 1
  opkg remove "$pkg" >/dev/null 2>&1 || true
  return 0
}

keenkit_present() {
  command -v keenkit >/dev/null 2>&1 && return 0
  [ -f /opt/keenkit.sh ] || [ -f /opt/bin/keenkit.sh ] || [ -L /opt/bin/keenkit ] && return 0
  return 1
}

keenkit_remove_all() {
  rm -f /opt/bin/keenkit /opt/keenkit.sh /opt/bin/keenkit.sh 2>/dev/null || true
  rm -f /opt/var/lib/flashkeen/keenkit_backup_dir 2>/dev/null || true
}

echo "Удаляю Flashkeen..."

rm -f \
  /opt/bin/flashkeen \
  /opt/bin/Flashkeen \
  /opt/bin/flash \
  /opt/bin/update \
  /opt/bin/flashkeen.sh \
  /opt/bin/uninstall-flashkeen.sh \
  /opt/bin/uninstall.sh \
  /opt/bin/F \
  /tmp/flashkeen-install.sh \
  /tmp/flashkeen-uninstall.sh \
  /opt/var/lib/flashkeen/skip_update_prompt_for_version \
  /opt/var/lib/flashkeen/latest_release_cache \
  /opt/var/lib/flashkeen/entware_bootstrap_stamp \
  /opt/var/lib/flashkeen/active_stage.state \
  /opt/var/lib/flashkeen/instance.lock \
  /opt/var/lib/flashkeen/console_tail.lock \
  /opt/var/lib/flashkeen/session_resize_check_seen.flag \
  /opt/var/lib/flashkeen/keenkit_backup_dir \
  /opt/var/lib/flashkeen/F \
  /tmp/flashkeen/F

rm -rf \
  /opt/var/lib/flashkeen/fsck_today \
  /opt/var/lib/flashkeen/op_state \
  /tmp/flashkeen \
  /tmp/flashkeen.op_state \
  2>/dev/null || true
rm -f /tmp/flashkeen* 2>/dev/null || true

for pf in /opt/etc/profile /root/.profile /opt/root/.profile; do
  remove_alias_in_profile_file "$pf" "flash" || true
  remove_alias_in_profile_file "$pf" "update" || true
  remove_alias_in_profile_file "$pf" "flashx" || true
done

if command -v opkg >/dev/null 2>&1; then
  removed_pkgs=""
  for pkg in ntfs-3g-utils e2fsprogs resize2fs tune2fs parted; do
    if opkg_remove_if_installed "$pkg"; then
      if [ -z "$removed_pkgs" ]; then
        removed_pkgs="$pkg"
      else
        removed_pkgs="$removed_pkgs $pkg"
      fi
    fi
  done
  [ -n "$removed_pkgs" ] && echo "Удалены пакеты: $removed_pkgs"

  printf "Удалить KeenSnap? (y/n): "
  read answer || answer=""
  case "$answer" in
    y|Y|yes|YES)
      opkg remove keensnap >/dev/null 2>&1 || true
      rm -f /opt/etc/opkg/keensnap.conf 2>/dev/null || true
      ;;
  esac
fi

if keenkit_present; then
  printf "Удалить KeenKit? (y/n): "
  read answer || answer=""
  case "$answer" in
    y|Y|yes|YES)
      keenkit_remove_all
      ;;
  esac
fi

echo "Готово."
