#!/bin/sh
set -e

echo "[1/6] Останавливаю процессы keensnap..."
pkill -f "/opt/root/KeenSnap/keensnap" 2>/dev/null || true
pkill -x keensnap 2>/dev/null || true

echo "[2/6] Удаляю файлы/ссылки Keensnap..."
rm -f /opt/bin/keensnap
rm -f /opt/etc/ndm/schedule.d/99-keensnap.sh
rm -rf /opt/root/KeenSnap

echo "[3/6] Удаляю логи/временные файлы..."
rm -f /opt/var/log/keensnap.log
rm -f /tmp/keensnap.sh /tmp/keensnap-init /tmp/install.sh

echo "[4/6] Проверяю, что ничего не осталось..."
command -v keensnap >/dev/null 2>&1 && echo "WARN: keensnap ещё в PATH" || echo "OK: keensnap удалён из PATH"
[ -e /opt/root/KeenSnap ] && echo "WARN: /opt/root/KeenSnap осталась" || echo "OK: /opt/root/KeenSnap удалена"
[ -e /opt/etc/ndm/schedule.d/99-keensnap.sh ] && echo "WARN: schedule-хук остался" || echo "OK: schedule-хук удалён"

echo "[5/6] (Опционально) Удаляю пакеты, которые Keensnap мог доустановить..."
# ВНИМАНИЕ: удаляй только если они не нужны другим скриптам
for p in coreutils-split wireguard-tools tar curl; do
  if opkg list-installed | grep -q "^$p "; then
    echo "Найден пакет: $p (оставляю на ваше усмотрение)"
    # opkg remove "$p"   # раскомментируй, если точно хочешь удалить
  fi
done

echo "[6/6] Готово."