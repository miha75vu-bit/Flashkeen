# Flashkeen — простое управление дисковыми разделами и перенос, установка Entware на Keenetic/Netcraze

`Flashkeen` — интерактивный консольный помощник для Keenetic (Entware), который превращает рутину с дисками и Entware в понятное меню из нескольких пунктов.  
Форматирование, разметка, резервное копирование с KeenSnap и перенос Entware на другой диск — всё в одном скрипте.


<img width="1195" height="536" alt="изображение" src="https://github.com/user-attachments/assets/af02c907-3f8d-4cf6-87ec-697bad3304b5" />

## Возможности

- **Подготовка раздела под Entware**
  - Быстрый выбор нужного раздела и форматирование в оптимальный `ext4` под Entware.
  - Автоматическая подстройка метки (`Entware USB` / `Entware SSD`) в зависимости от размера диска.

- **Полное управление разделами USB‑диска**
  - Создание новой GPT‑разметки диска с нужным количеством разделов.
  - Форматирование разделов в:
    - `ext4` (с журналом или без),
    - `ntfs`,
    - `swap`.
  - Создание раздела в свободном месте без трогания существующих.
  - Удаление разделов через удобное меню.

- **Резервное копирование и автоматический перенос Entware (KeenSnap)**
  - Интеграция с [KeenSnap](https://github.com/spatiumstas/keensnap):
    - `Создать бекап` (ручной запуск бэкапа).
    - `Перенести Entware из резервной копии на другой диск/раздел`.
    - `Распаковать бекап в ту же папку`.
    - `Настройки KeenSnap` — запуск основного интерфейса KeenSnap.
  - Авто‑проверка и, при желании, установка KeenSnap, если он ещё не установлен.
  - Список бэкапов:
    - сортировка **от новых к старым** по дате файла;
    - вывод **читаемого размера** (`du -h`).

- **Обновление Entware**
  - Отдельный пункт меню:
    - `opkg update && opkg upgrade`
  - Вывод всех сообщений `opkg` прямо в интерфейсе Flashkeen.

- **Удобный запуск из Entware**
  - При первом запуске скрипт сам устанавливается в `/opt/bin` и создаёт команды:
    - `flashkeen`
    - `Flashkeen`
    - `flash`
  - Дальнейший запуск из Entware сводится к вводу одной короткой команды.

## Требования

- Роутер Keenetic с включённой поддержкой Entware.
- Установленное Entware.
- Доступ к `opkg` (для установки `parted`, `tune2fs`, `ntfs-3g-utils`, `curl` и самого KeenSnap при необходимости).

## Установка

opkg update && opkg install curl && \
curl -L -s "https://raw.githubusercontent.com/miha75vu-bit/Flashkeen/main/install.sh" > /tmp/flashkeen-install.sh && \
sh /tmp/flashkeen-install.sh

## Удаление
curl -L -s "https://raw.githubusercontent.com/miha75vu-bit/Flashkeen/main/uninstall.sh" > /tmp/flashkeen-uninstall.sh && \
sh /tmp/flashkeen-uninstall.sh
