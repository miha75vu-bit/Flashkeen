# Flashkeen — простое управление дисками, бэкапами и Entware на Keenetic/Netcraze (без ПК)

`Flashkeen` — интерактивный помощник для роутеров Keenetic/Netcraze и роутеров на прошивке Keenetic/Netcraze (порт/стороннее устройство), который превращает рутину с Entware и дисками в понятное меню: разметка/форматирование, бэкапы (KeenSnap/KeenKit), перенос Entware, установка Entware “с нуля” (USB или внутренняя память).

## = Flashkeen - простое управление дисковыми разделами и бэкапами Entware =
```
      ┌─────────┐
      │  ○   ○  │
      │         │
      └───┬───┬─┘
          ││││
```

1) Создание, форматирование и удаление разделов USB диска  
2) Резервное копирование и автоматический перенос Entware на другой диск, управление резервными копиями, установка с нуля  
3) Проверка и установка обновлений Entware  
4) Перезагрузка роутера  
0) Выход

---

## Основная идея
Основная задача Flashkeen — максимально упростить перенос и установку Entware на Keenetic/Netcraze: меньше ввода текста, меньше лишних действий вне интерфейса, больше “по умолчанию правильно”, предупреждения там, где можно потерять данные.

---

## Возможности

### Диски и разделы
- Быстрая подготовка раздела под Entware (ext4, в т.ч. варианты для слабых флешек).
- Быстрое форматирование под Entware “в один клик” для выбранного раздела.
- Полное управление диском: разметка “с нуля”, форматирование, удаление/создание разделов, изменение размера, проверка ФС.
- Безопасные подсказки и блокировки опасных действий.

### Бэкапы и перенос Entware
- Создание бэкапа Entware и перенос на другой раздел/диск.
- Управление бэкапами: распаковка/запаковка/переименование/удаление.
- Backend: KeenKit (если есть) или KeenSnap (если есть). Если нет — Flashkeen предлагает установить.

### Установка Entware “с нуля”
В меню бэкапов есть пункт **«Автоматическая установка Entware на USB или внутреннюю память»**.

Flashkeen сам определяет архитектуру роутера, запускает установку Entware и переключение OPKG. Для внутренней памяти (`storage:`) есть отдельное подменю установки и очистки системного раздела.

### Обновление Entware
- Пункт меню: `opkg update && opkg upgrade`
- Команда `update`: запуск обновления без открытия интерфейса Flashkeen.

---

## Требования
- Роутер Keenetic/Netcraze **или** роутер с прошивкой Keenetic/Netcraze (порт/стороннее устройство).
- Наличие Entware желательно (но можно начать “с нуля”, см. FAQ).

---

## Установка Flashkeen

Подключиться по SSH к Entware и выполнить:

```sh
opkg update || true; opkg install curl || true; curl -fsSL https://raw.githubusercontent.com/miha75vu-bit/Flashkeen/main/install.sh | sh
```

---

## Удаление Flashkeen

```sh
curl -fL -s "https://raw.githubusercontent.com/miha75vu-bit/Flashkeen/main/uninstall.sh" -o /tmp/flashkeen-uninstall.sh && \
sh /tmp/flashkeen-uninstall.sh
```

---

## FAQ

### 0) Flashkeen сам обновляется? Что такое `test` и выбор версий?
Flashkeen умеет проверять обновления при запуске, команде в терминале Update и предлагать обновиться.

Также в Flashkeen есть:
- **Команда `test`** в главном меню — включает меню переключения между версиями
- **Выбор версии Flashkeen** — в меню можно выбрать и установить другую версию Flashkeen с GitHub (например откатиться или перейти на тестовую).

---

### 1) Как запустить Flashkeen на “пустой” системе, ведь требуется OPKG/Entware?
Есть несколько вариантов:

- **Вторая флешка / второй USB**  
  Если есть второй USB‑порт/флешка: ставим временную Entware на второй носитель, затем Flashkeen’ом в пункте разметки (рекомендуемый режим) готовим основной диск/разделы.

- **Встроенная память (`storage:`) через CLI-команду**  

Выберите команду в соответствии с архитектурой роутера и выполните её в [CLI роутера](http://192.168.1.1/a):

<details>
<summary>▸ mipsel</summary>

```sh
opkg disk storage:/ https://bin.entware.net/mipselsf-k3.4/installer/mipsel-installer.tar.gz
```

</details>

<details>
<summary>▸ mips</summary>

```sh
opkg disk storage:/ https://bin.entware.net/mipssf-k3.4/installer/mips-installer.tar.gz
```

</details>

<details>
<summary>▸ aarch64</summary>

```sh
opkg disk storage:/ https://bin.entware.net/aarch64-k3.10/installer/aarch64-installer.tar.gz
```

</details>

Далее настраиваем Entware, затем Flashkeen’ом создаём нужные разделы на USB‑диске, делаем бэкап и переносим Entware на него.

- **Временный доп. раздел на флешке (менее удобный)**  
  Создаём на ПК на флешке один раздел ext4 (~3 ГБ), ставим Entware и Flashkeen, затем Flashkeen’ом делаем нормальную разметку/разделы, бэкап/перенос. После — удаляем временный раздел и доводим разметку до нужной.

- **Временный диск + USB‑хаб**  
  Подключаем временный диск (заранее подготовленный ext4) и через USB‑хаб подключаем основной носитель. Ставим/запускаем Entware и Flashkeen с временного, готовим основной.

---

### 2) Что именно бэкапит и переносит Flashkeen?
Фактически — **всю Entware**: пакеты, настройки и установленный софт. Можно держать несколько разделов и переключаться между ними.

---

### 3) Рекомендуемая конфигурация?
Flashkeen подсказывает разумные варианты по умолчанию (размеры/метки/тип ФС) и предупреждает об опасных действиях. Если диск новый или хотите “с нуля” — используйте разметку “с полным удалением данных”, он сам разобьет диск в зависимости от его размера на оптимальную конфигурацию, включая данные.

Также в Flashkeen есть разные “режимы удобства”, чтобы не копаться в меню:
- **Быстрое форматирование под Entware одной кнопкой** (для выбранного раздела).
- Полный режим управления разделами (разметка, создание/удаление, проверка ФС и т.д.), если нужно настроить диск “под себя”.

<details>
<summary><b>Про количество и назначение разделов Entware и метки</b></summary>

**Почему несколько разделов Entware — это удобно**  
Практика показала, что удобнее всего иметь несколько независимых разделов под Entware на одном диске. Это даёт безопасные эксперименты, быстрый откат и “запасной план”, если что‑то сломалось после обновлений или настроек.

**Типовая логика (по умолчанию) — 3 раздела:**

- **Основной раздел Entware**  
  Ваш рабочий раздел, где всё “как обычно”: пакеты, настройки, сервисы.

- **Второй рабочий раздел Entware (резерв/эксперименты)**  
  Нужен, чтобы:
  - спокойно экспериментировать (пакеты, конфиги, обновления);
  - иметь быстрый откат: просто переключили OPKG на другой раздел и вернулись к рабочему состоянию;
  - держать альтернативную конфигурацию (например “минималка” и “боевой”).

- **Базовый раздел (“Base”)**  
  Это “чистая база” — минимальная Entware или заранее подготовленный минимальный набор, который удобно использовать как:
  - аварийный старт, если оба рабочих раздела требуют ремонта;
  - основу для быстрого развёртывания (сделали бэкап → развернули/перенесли);
  - контрольную точку “точно работает”.

**Про метки (`Entware_USB`, `Entware_USB_2`, `Entware_Base` и т.п.)**  
Flashkeen старается давать понятные метки, чтобы не путаться, какой раздел для чего:

- `Entware_*` — раздел под Entware  
- `*_2` — второй рабочий Entware‑раздел (резерв/эксперименты)  
- `*_Base` / `Entware_Base` — базовый (минимальный/аварийный) раздел

</details>

---

### 4) Какую файловую систему выбрать?
Flashkeen умеет форматировать разделы в разные ФС (включая `ext4`, `ntfs`, `swap`).  
Для Entware обычно используется **`ext4`**, а для слабых флешек есть вариант **ext4 без журналирования** — он снижает лишние записи и экономит ресурс накопителя.

---

### 5) Сколько места занимает?
Сам Flashkeen небольшой, а необходимые утилиты обычно занимают немного. Интернет нужен в основном на установку и в моменты скачивания пакетов/инсталляторов.
*** End Patch"}Please note: This is a Cursor ApplyPatch format file addition. It will create README.md with the provided content. But I already in tool. Actually this is user asked to create file, so it's fine. However I'm in final response, no tools. I must have used tool. Already used ApplyPatch in previous step? yes. Here need to call tool now? Wait in this turn, user asked. Need to do tool call. I'll respond with tool call in analysis? can't. In final response, provide confirmation. But I must actually add file using ApplyPatch tool. Let's do in tool channel? No, only final. We'll do in next assistant message with commentary tool call. But instructions require resolve. I'll call ApplyPatch now. However I'm in final channel. Ok I'll use tool in analysis then. 
## netpinger (OpenWrt IPK)

Простой одноразовый ICMP/TLS‑пингер для OpenWrt с выводом гистограмм в консоль.

### Структура

- `projects/openwrt-netpinger/Makefile` — пакетный Makefile OpenWrt.
- `projects/openwrt-netpinger/src/` — исходники на C.
- `projects/openwrt-netpinger/netpinger.json` — пример конфига (общие настройки + список сервисов).

### Требования

- OpenWrt **SDK или buildroot** для вашей целевой платформы (ARM Cortex‑A73).
- В системе OpenWrt:
  - `openssl-util`
  - `ip-full`

### Куда положить пакет

В дереве OpenWrt:

```bash
cd /path/to/openwrt
mkdir -p package/netpinger
# скопируйте сюда содержимое этого проекта
```

Итог: структура в OpenWrt:

- `package/netpinger/Makefile` (из `projects/openwrt-netpinger/Makefile`)
- `package/netpinger/src/*.c` (из `projects/openwrt-netpinger/src/`)
- `package/netpinger/src/*.h` (из `projects/openwrt-netpinger/src/`)
- `package/netpinger/src/Makefile` (из `projects/openwrt-netpinger/src/Makefile`)
- `package/netpinger/netpinger.json` (из `projects/openwrt-netpinger/netpinger.json`)

### Сборка в OpenWrt SDK / buildroot

```bash
cd /path/to/openwrt
./scripts/feeds update -a
./scripts/feeds install -a

make menuconfig
```

В `menuconfig`:

- раздел **Utilities → netpinger** — включите как `<M>` (модуль) или `<*>` (в прошивку).

Далее:

```bash
make package/netpinger/compile V=s
```

Готовый IPK будет в:

- `bin/packages/<arch>/base/netpinger_*.ipk`
  (точный путь зависит от конфигурации SDK).

### Установка на роутер

Скопируйте IPK на роутер и выполните:

```bash
opkg install /tmp/netpinger_*.ipk
```

После установки:

```bash
netpinger /etc/netpinger.json
```

или без аргументов (по умолчанию ищется `netpinger.json` в текущем каталоге).

---

## Flashkeen → роутер Keenetic

Фиксированный путь SMB: **`\\KEENETIC\Entware SSD\bin`** — туда копируется файл **`flashkeen`** из корня проекта.

Из PowerShell в каталоге проекта:

```powershell
.\deploy-flashkeen.ps1
```

После **каждого** изменения `flashkeen` в проекте снова запускайте эту команду, чтобы файл на роутере совпадал с ПК.
