#!/bin/sh
set -e

echo "Удаляю Flashkeen из /opt/bin..."

rm -f \
  /opt/bin/flashkeen \
  /opt/bin/Flashkeen \
  /opt/bin/flash \
  /opt/bin/update \
  /opt/bin/flashkeen.sh \
  /tmp/flashkeen-install.sh \
  /tmp/flashkeen-uninstall.sh

# Опционально убираем служебные файлы проверки обновлений
rm -f /opt/var/lib/flashkeen/skip_update_prompt_for_version \
      /opt/var/lib/flashkeen/latest_release_cache

echo "Готово. Если запускали с флешки/шары — исходный файл там останется, удалите его вручную при необходимости."
