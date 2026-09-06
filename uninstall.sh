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

# Если пакет уже не установлен — убрать оставшиеся бинарники core-утилит.
opkg_purge_core_tool_orphans() {
  _rm_bins() {
    for _b in "$@"; do
      [ -n "$_b" ] || continue
      for _d in /opt/sbin /opt/bin; do
        if [ -e "$_d/$_b" ] || [ -L "$_d/$_b" ]; then
          rm -f "$_d/$_b" 2>/dev/null || true
        fi
      done
    done
  }
  opkg list-installed 2>/dev/null | grep -q '^parted ' || _rm_bins parted
  opkg list-installed 2>/dev/null | grep -q '^e2fsprogs ' || _rm_bins e2fsck mkfs.ext4 mke2fs fsck.ext4 badblocks
  opkg list-installed 2>/dev/null | grep -q '^tune2fs ' || _rm_bins tune2fs
  opkg list-installed 2>/dev/null | grep -q '^resize2fs ' || _rm_bins resize2fs
  opkg list-installed 2>/dev/null | grep -q '^ntfs-3g-utils ' || _rm_bins ntfsfix mkfs.ntfs ntfsresize
  opkg list-installed 2>/dev/null | grep -q '^psmisc ' || _rm_bins fuser
  hash -r 2>/dev/null || true
}

keenkit_present() {
  [ -f /opt/keenkit.sh ] && return 0
  [ -f /opt/bin/keenkit.sh ] && return 0
  [ -f /opt/bin/keenkit ] && return 0
  [ -e /opt/keenkit.sh ] && return 0
  [ -e /opt/bin/keenkit ] && return 0
  _kk=$(command -v keenkit 2>/dev/null || true)
  case "$_kk" in
    /*)
      [ -e "$_kk" ] && return 0
      ;;
  esac
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
  _kk=$(command -v keenkit 2>/dev/null || true)
  for _f in /opt/bin/keenkit /opt/keenkit.sh /opt/bin/keenkit.sh /opt/keenkit "$_kk"; do
    [ -n "$_f" ] || continue
    case "$_f" in
      /*) ;;
      *) continue ;;
    esac
    if [ -e "$_f" ] || [ -L "$_f" ]; then
      chmod u+w "$_f" 2>/dev/null || true
      rm -f "$_f" 2>/dev/null || true
    fi
  done
  [ -L /opt/bin/keenkit ] && rm -f /opt/bin/keenkit 2>/dev/null || true
  [ -L /opt/keenkit.sh ] && rm -f /opt/keenkit.sh 2>/dev/null || true
  rm -f /opt/var/lib/flashkeen/keenkit_backup_dir 2>/dev/null || true
  hash -r 2>/dev/null || true
}

restore_opkg_feeds() {
  # Снять офлайн/full file:// фиды Flashkeen. Штатные entware/keendev не выдумываем.
  _strip_fk_feed_file() {
    _ff="$1"
    [ -f "$_ff" ] || return 0
    _tmp="/tmp/flashkeen.distfeeds.uninstall.$$"
    grep -vE 'flashkeen_full_all|flashkeen_offline_|file:///opt/share/flashkeen' "$_ff" > "$_tmp" 2>/dev/null || : > "$_tmp"
    if [ -s "$_tmp" ]; then
      mv -f "$_tmp" "$_ff" 2>/dev/null || rm -f "$_tmp"
    else
      rm -f "$_tmp" "$_ff" 2>/dev/null || true
    fi
  }

  _has_entware_feeds() {
    _ff="$1"
    [ -f "$_ff" ] || return 1
    grep -qE 'bin\.entware\.net|entware\.ru' "$_ff" 2>/dev/null
  }

  _customfeeds_has_entware_keendev() {
    _cf="/opt/etc/opkg/customfeeds.conf"
    [ -f "$_cf" ] || return 1
    grep -qE '^[[:space:]]*src/gz[[:space:]]+entware([[:space:]]|$)' "$_cf" 2>/dev/null || return 1
    grep -qE '^[[:space:]]*src/gz[[:space:]]+keendev([[:space:]]|$)' "$_cf" 2>/dev/null || return 1
    return 0
  }

  _dedupe_opkg_entware_feeds() {
    _df="/opt/etc/opkg/distfeeds.conf"
    [ -f "$_df" ] || return 0
    _customfeeds_has_entware_keendev || return 0
    rm -f "$_df" 2>/dev/null || true
  }

  _restore_distfeeds_from_stash() {
    _customfeeds_has_entware_keendev && return 1
    _best=""
    for _bak in /tmp/flashkeen.full.distfeeds.* /tmp/flashkeen.distfeeds.*; do
      [ -f "$_bak" ] || continue
      _has_entware_feeds "$_bak" || continue
      _best="$_bak"
      break
    done
    [ -n "$_best" ] || return 1
    mkdir -p /opt/etc/opkg 2>/dev/null || true
    cp -f "$_best" /opt/etc/opkg/distfeeds.conf 2>/dev/null || return 1
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
    _restore_distfeeds_from_stash || true
  fi
  _dedupe_opkg_entware_feeds
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
  # Пакеты, которые Flashkeen поставил (снимок до/после core), + --autoremove.
  # Порядок: сначала утилиты, потом типичные libs — opkg не снимет то, что ещё нужно другим.
  _owned="/opt/var/lib/flashkeen/core_pkgs_owned.list"
  if [ -f "$_owned" ]; then
    _order="ntfs-3g-utils resize2fs tune2fs parted e2fsprogs ntfs-3g psmisc libparted libe2p libext2fs libss libcomerr libblkid libuuid libfuse libgcrypt libgpg-error libreadline libncurses libncursesw terminfo"
    _todo=""
    while IFS= read -r pkg || [ -n "$pkg" ]; do
      pkg=$(printf '%s' "$pkg" | tr -d '\r')
      [ -n "$pkg" ] || continue
      [ "$pkg" = "curl" ] && continue
      _todo="$_todo $pkg"
    done < "$_owned"
    for pkg in $_order; do
      case " $_todo " in
        *" $pkg "*)
          if opkg_remove_if_installed "$pkg"; then
            if [ -z "$removed_pkgs" ]; then
              removed_pkgs="$pkg"
            else
              removed_pkgs="$removed_pkgs $pkg"
            fi
            _todo=$(printf '%s' "$_todo" | sed "s/[[:space:]]*$pkg[[:space:]]*/ /g")
          fi
          ;;
      esac
    done
    for pkg in $_todo; do
      [ -n "$pkg" ] || continue
      if opkg_remove_if_installed "$pkg"; then
        if [ -z "$removed_pkgs" ]; then
          removed_pkgs="$pkg"
        else
          removed_pkgs="$removed_pkgs $pkg"
        fi
      fi
    done
    # Хвосты: пакет снят из opkg, а бинарник остался — система потом думает, что всё есть.
    opkg_purge_core_tool_orphans
  else
    echo "Список пакетов Flashkeen не найден — parted/e2fsprogs/… не снимаю (могли быть до установки)."
  fi
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
        rm -f /opt/etc/opkg/keensnap.conf /opt/etc/opkg/feedly.conf 2>/dev/null || true
        # opkg оставляет Conffiles (config.conf) — иначе при следующей установке resolve_conffiles.
        rm -rf /opt/root/KeenSnap 2>/dev/null || true
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
