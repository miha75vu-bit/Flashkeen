#!/bin/sh
# Удаление Flashkeen. Канон: flashkeen/installers/uninstall.sh
# curl -fsSL .../flashkeen/installers/uninstall.sh | sh  (или скачать и sh)

echo "Uninstall: Flashkeen"

opkg_ensure_unlocked() {
  lock=/opt/tmp/opkg.lock
  pids=""
  if command -v pidof >/dev/null 2>&1; then
    pids=$(pidof opkg 2>/dev/null || true)
  fi
  if [ -z "$pids" ] && command -v fuser >/dev/null 2>&1 && [ -e "$lock" ]; then
    pids=$(fuser "$lock" 2>/dev/null | tr -cs '0-9' ' ')
  fi
  if [ -n "$pids" ]; then
    for pid in $pids; do
      case "$pid" in ''|*[!0-9]*|$$) continue ;; esac
      kill "$pid" 2>/dev/null || true
    done
    sleep 1
  fi
  [ -e "$lock" ] && rm -f "$lock" 2>/dev/null || true
}

read_tty_line() {
  if [ -c /dev/tty ] 2>/dev/null; then
    IFS= read -r REPLY < /dev/tty
  else
    IFS= read -r REPLY
  fi
  printf '%s' "$REPLY" | tr -d '\r'
}

answer_is_yes() {
  case "$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

answer_is_no() {
  case "$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')" in
    n|no) return 0 ;;
    *) return 1 ;;
  esac
}

print_yes_no_invalid() {
  _ans=$(printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
  case "$_ans" in
    y|yes|n|no) return 1 ;;
    д|да|н|нет|у)
      echo "Введена кириллица. Используйте латинские y (да) или n (нет)."
      return 0
      ;;
    "")
      echo "Пустой ввод. Используйте y (да) или n (нет)."
      return 0
      ;;
    *)
      echo "Неверный ввод. Используйте только латинские y (да) или n (нет)."
      return 0
      ;;
  esac
}

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
  opkg remove --autoremove "$pkg" >/dev/null 2>&1
  opkg list-installed 2>/dev/null | grep -q "^${pkg} " && return 1
  return 0
}

keenkit_present() {
  command -v keenkit >/dev/null 2>&1 && return 0
  [ -f /opt/keenkit.sh ] || [ -f /opt/bin/keenkit.sh ] || [ -L /opt/bin/keenkit ] && return 0
  return 1
}

keensnap_present() {
  [ -f /opt/root/KeenSnap/keensnap.sh ] && return 0
  command -v keensnap >/dev/null 2>&1 && return 0
  [ -f /opt/bin/keensnap ] && return 0
  if command -v opkg >/dev/null 2>&1; then
    opkg list-installed 2>/dev/null | grep -q "^keensnap " && return 0
  fi
  return 1
}

keenkit_remove_all() {
  rm -f /opt/bin/keenkit /opt/keenkit.sh /opt/bin/keenkit.sh 2>/dev/null || true
  rm -f /opt/var/lib/flashkeen/keenkit_backup_dir 2>/dev/null || true
}

restore_opkg_feeds() {
  # Снять офлайн/full file:// фиды Flashkeen и вернуть обычные Entware, если их затёрли.
  _strip_fk_feed_file() {
    _ff="$1"
    [ -f "$_ff" ] || return 0
    _tmp="/tmp/flashkeen.distfeeds.uninstall.$$"
    grep -vE 'flashkeen_full_all|flashkeen_offline_|file:///opt/share/flashkeen' "$_ff" > "$_tmp" 2>/dev/null || : > "$_tmp"
    if [ -s "$_tmp" ]; then
      mv -f "$_tmp" "$_ff" 2>/dev/null || rm -f "$_tmp"
    else
      rm -f "$_tmp"
      : > "$_ff"
    fi
  }

  _has_entware_feeds() {
    _ff="$1"
    [ -f "$_ff" ] || return 1
    grep -qE 'bin\.entware\.net|entware\.ru' "$_ff" 2>/dev/null
  }

  _restore_distfeeds_from_stash() {
    _best=""
    for _bak in /tmp/flashkeen.full.distfeeds.* /tmp/flashkeen.distfeeds.*; do
      [ -f "$_bak" ] || continue
      _has_entware_feeds "$_bak" || continue
      _best="$_bak"
      break
    done
    [ -n "$_best" ] || return 1
    cp -f "$_best" /opt/etc/opkg/distfeeds.conf 2>/dev/null || return 1
    return 0
  }

  _write_default_entware_distfeeds() {
    _arch=$(opkg print-architecture 2>/dev/null | grep -oE 'mips-3|mipsel-3|aarch64-3' | head -n 1)
    _base=""
    case "$_arch" in
      mips-3) _base="http://bin.entware.net/mipssf-k3.4" ;;
      mipsel-3) _base="http://bin.entware.net/mipselsf-k3.4" ;;
      aarch64-3) _base="http://bin.entware.net/aarch64-k3.10" ;;
      *) return 1 ;;
    esac
    mkdir -p /opt/etc/opkg 2>/dev/null || true
    {
      echo "src/gz entware $_base"
      echo "src/gz keendev ${_base}/keenetic"
    } > /opt/etc/opkg/distfeeds.conf
    return 0
  }

  for _df in /opt/etc/opkg/distfeeds.conf /opt/etc/opkg/customfeeds.conf /opt/etc/opkg.conf; do
    _strip_fk_feed_file "$_df"
  done
  for _df in /opt/etc/opkg/*.conf; do
    [ -f "$_df" ] || continue
    case "$_df" in
      */distfeeds.conf|*/customfeeds.conf) continue ;;
      */flashkeen-full.conf|*/flashkeen-offline.conf) rm -f "$_df"; continue ;;
    esac
    grep -qE 'flashkeen_full_all|flashkeen_offline_|file:///opt/share/flashkeen' "$_df" 2>/dev/null || continue
    _strip_fk_feed_file "$_df"
    [ -s "$_df" ] || rm -f "$_df"
  done
  rm -f /opt/etc/opkg/flashkeen-full.conf /opt/etc/opkg/flashkeen-offline.conf 2>/dev/null || true

  if ! _has_entware_feeds /opt/etc/opkg/distfeeds.conf; then
    _restore_distfeeds_from_stash || _write_default_entware_distfeeds || true
  fi
}

echo "Удаляю Flashkeen..."

if command -v opkg >/dev/null 2>&1; then
  opkg_ensure_unlocked
fi

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
  /tmp/flashkeen/F

if command -v opkg >/dev/null 2>&1; then
  # Сначала вернуть фиды (пока живы бэкапы в /tmp), потом снять пакеты и бандлы.
  restore_opkg_feeds

  removed_pkgs=""
  for pkg in flashkeen-installer flashkeen; do
    if opkg_remove_if_installed "$pkg"; then
      if [ -z "$removed_pkgs" ]; then
        removed_pkgs="$pkg"
      else
        removed_pkgs="$removed_pkgs $pkg"
      fi
    fi
  done
  for pkg in ntfs-3g-utils resize2fs tune2fs parted e2fsprogs psmisc upx; do
    if opkg_remove_if_installed "$pkg"; then
      if [ -z "$removed_pkgs" ]; then
        removed_pkgs="$pkg"
      else
        removed_pkgs="$removed_pkgs $pkg"
      fi
    fi
  done
  [ -n "$removed_pkgs" ] && echo "Удалены пакеты: $removed_pkgs"
fi

# Офлайн-бандлы и состояние Flashkeen (IPK на дисках / USB не трогаем).
rm -rf \
  /opt/var/lib/flashkeen \
  /opt/share/flashkeen \
  /opt/share/flashkeen-full \
  /opt/share/flashkeen-offline \
  /tmp/flashkeen \
  /tmp/flashkeen.op_state \
  2>/dev/null || true

rm -f \
  /tmp/flashkeen.distfeeds.* \
  /tmp/flashkeen.full.distfeeds.* \
  /tmp/flashkeen.ipk.* \
  /tmp/flashkeen-ipk.* \
  2>/dev/null || true

for pf in /opt/etc/profile /root/.profile /opt/root/.profile; do
  remove_alias_in_profile_file "$pf" "flash" || true
  remove_alias_in_profile_file "$pf" "update" || true
  remove_alias_in_profile_file "$pf" "flashx" || true
done

if command -v opkg >/dev/null 2>&1; then
  if keensnap_present; then
    while true; do
      printf "Удалить KeenSnap? (y/n): "
      answer=$(read_tty_line)
      if answer_is_yes "$answer"; then
        opkg_ensure_unlocked
        opkg remove --autoremove keensnap >/dev/null 2>&1 || true
        rm -f /opt/etc/opkg/keensnap.conf 2>/dev/null || true
        break
      fi
      if answer_is_no "$answer"; then
        break
      fi
      print_yes_no_invalid "$answer" || true
    done
  fi
fi

if keenkit_present; then
  while true; do
    printf "Удалить KeenKit? (y/n): "
    answer=$(read_tty_line)
    if answer_is_yes "$answer"; then
      keenkit_remove_all
      break
    fi
    if answer_is_no "$answer"; then
      break
    fi
    print_yes_no_invalid "$answer" || true
  done
fi

echo "Готово."
rm -f /tmp/flashkeen-uninstall.sh /tmp/flashkeen-install.sh 2>/dev/null || true
