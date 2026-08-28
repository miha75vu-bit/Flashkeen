#!/bin/sh

echo "Uninstall: Flashkeen"

remove_alias_in_profile_file() {
  profile_file="$1"
  alias_name="$2"
  [ -n "$alias_name" ] || return 1
  [ -f "$profile_file" ] || return 0

  tmp_file="/tmp/flashkeen-uninstall.profile.$$.$alias_name"
  awk -v alias_name="$alias_name" '$0 !~ ("^alias " alias_name "=")' "$profile_file" > "$tmp_file" 2>/dev/null || {
    rm -f "$tmp_file" 2>/dev/null
    return 1
  }
  mv "$tmp_file" "$profile_file" 2>/dev/null || {
    rm -f "$tmp_file" 2>/dev/null
    return 1
  }
}

opkg_remove_if_installed() {
  pkg="$1"
  opkg list-installed 2>/dev/null | grep -q "^${pkg} " || return 1
  opkg remove --autoremove "$pkg" >/dev/null 2>&1
  opkg list-installed 2>/dev/null | grep -q "^${pkg} " && return 1
  return 0
}

keenkit_present() {
  command -v keenkit >/dev/null 2>&1 && return 0
  [ -f /opt/keenkit.sh ] || [ -f /opt/bin/keenkit.sh ] || [ -L /opt/bin/keenkit ]
}

echo "Удаляю Flashkeen..."

rm -f \
  /opt/bin/flashkeen \
  /opt/bin/Flashkeen \
  /opt/bin/flash \
  /opt/bin/flashx \
  /opt/bin/update \
  /opt/bin/flashkeen.sh \
  /opt/bin/uninstall-flashkeen.sh \
  /opt/bin/uninstall.sh \
  /opt/bin/F \
  2>/dev/null

rm -rf /opt/var/lib/flashkeen /tmp/flashkeen /tmp/flashkeen.op_state 2>/dev/null
rm -f /tmp/flashkeen* 2>/dev/null

for pf in /opt/etc/profile /root/.profile /opt/root/.profile; do
  remove_alias_in_profile_file "$pf" "flash"
  remove_alias_in_profile_file "$pf" "update"
  remove_alias_in_profile_file "$pf" "flashx"
done

if command -v opkg >/dev/null 2>&1; then
  removed_pkgs=""
  for pkg in ntfs-3g-utils resize2fs tune2fs parted e2fsprogs; do
    if opkg_remove_if_installed "$pkg"; then
      removed_pkgs="${removed_pkgs:+$removed_pkgs }$pkg"
    fi
  done
  [ -n "$removed_pkgs" ] && echo "Удалены пакеты: $removed_pkgs"

  printf "Удалить KeenSnap? (y/n): "
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES|д|Д|да|ДА)
      opkg remove --autoremove keensnap >/dev/null 2>&1
      rm -f /opt/etc/opkg/keensnap.conf /opt/etc/opkg/feedly.conf 2>/dev/null
      ;;
  esac
fi

if keenkit_present; then
  printf "Удалить KeenKit? (y/n): "
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES|д|Д|да|ДА)
      rm -f /opt/bin/keenkit /opt/keenkit.sh /opt/bin/keenkit.sh 2>/dev/null
      ;;
  esac
fi

echo "Готово."
