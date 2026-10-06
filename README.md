# Автонастройка рабочих систем: Ubuntu 25.10 и Omarchy

Репозиторий содержит скрипты для быстрого развёртывания рабочего окружения, восстановления конфигов из зашифрованной копии и переезда между системами.

| Система | Скрипт | Назначение |
|---|---|---|
| Ubuntu 25.10 | `ubuntu-setup-flags.sh` | Установка пакетов, Docker, Kubernetes, Zsh, GNOME и восстановление конфигов |
| Omarchy (Arch, Hyprland) | `omarchy-bootstrap.sh` | Бэкап с Ubuntu/Fedora/Omarchy, установка, dotfiles, плагины, восстановление |
| Zen Browser | `zen_browser_install.sh` | Модуль для Ubuntu-скрипта, вызывается автоматически |

## Содержание

- [Omarchy: backup, restore, bootstrap](#omarchy-backup-restore-bootstrap)
- [Ubuntu 25.10 Automated Setup](#ubuntu-2510-automated-setup)
- [Общие правила безопасности](#общие-правила-безопасности)

---

# Omarchy: backup, restore, bootstrap

`omarchy-bootstrap.sh` — один повторно запускаемый скрипт. Запускай его обычным пользователем, не через `sudo`: он сам вызывает `sudo` там, где это нужно.

## Режимы

```text
omarchy-bootstrap.sh backup [--backup-root DIR]
omarchy-bootstrap.sh setup [options]
omarchy-bootstrap.sh restore --from BACKUP_DIR [--force]
omarchy-bootstrap.sh all --from BACKUP_DIR [options]
omarchy-bootstrap.sh calendar-auth
omarchy-bootstrap.sh verify
```

| Режим | Что делает |
|---|---|
| `backup` | Собирает приватные данные и инвентаризацию на Ubuntu, Fedora или Omarchy; создаёт один GPG-архив и `SHA256SUMS` |
| `setup` | Ставит пакеты, клонирует dotfiles, применяет Stow, настраивает локаль, hosts, NFS, плагины, Docker, Plymouth |
| `restore` | Восстанавливает приватные данные из бэкапа, сделанного этим скриптом |
| `all` | `setup`, затем `restore`, затем запуск служб |
| `calendar-auth` | Интерактивный OAuth-мастер плагина Google Calendar |
| `verify` | Проверяет команды, службы, Hyprland, hosts, NFS и ThinkPad-модули |

## Опции

```text
--from DIR          каталог одного бэкапа (с private-home.tar.gz.gpg)
--backup-root DIR   родительский каталог новых бэкапов
--thinkpad          настройки ThinkPad X1 Carbon Gen 9 (WWAN, Bluetooth, fprintd)
--with-tlp          дополнительно TLP с порогами заряда 75/80
--skip-docker       не устанавливать и не настраивать Docker
--skip-plymouth     не скрывать логотип Omarchy при загрузке
--skip-mount        записать NFS в fstab, но не монтировать
--calendar-auth     в конце запустить мастер Google Calendar
--force             повторно восстановить уже применённый бэкап
--dry-run           показывать изменяющие команды без выполнения
```

## Что автоматизировано

- **Dotfiles**: клон `https://github.com/toxusa/dotfiles.git` в `~/.dotfiles`; Stow-пакеты `bash_omarchy`, `starship`, `batcat`, `zellij`, `vpn_omarchy`, `foot`, `hypr_omarchy`.
- **Пакеты**: Git, GitHub CLI, Stow, `lsd`, `mdcat`, `translate-shell`, `sdcv`, Zellij, Glow, MPV, `yt-dlp`, Docker, Syncthing, kubectl, Helm, k9s, `gws`; из AUR — `yandex-disk`, ble.sh, AmneziaWG, словари.
- **Локаль**: `LANG=en_US.UTF-8`, `LC_TIME=en_GB.UTF-8` (неделя с понедельника, 24 часа).
- **Сеть**: управляемый блок Homelab в `/etc/hosts`; NFS `192.168.1.10:/data/nas/files` → `/media/files`.
- **Плагины Omarchy**: `vbrosseau.alttab` и `tmn73.calendar`; календарь заменяет штатные часы в `~/.config/omarchy/shell.json`.
- **Google Cloud и Workspace CLI**: `gcloud` в `~/.local/share/google-cloud-sdk`, `gws` из репозитория Arch.
- **Загрузка**: прозрачный логотип Plymouth и `limine-update`.
- **Docker**: `docker.socket` и группа `docker`.
- **ThinkPad X1 Carbon Gen 9**: ModemManager и FCC unlock, WWAN выключен, `AutoEnable=false` для Bluetooth, пакет `fprintd`.

Настройки Foot, Hyprland, Bash/ble.sh, раскладки, Alt+Tab-биндов и VPN-скриптов приходят из dotfiles.

## Что входит в бэкап

SSH, GnuPG, Git, Syncthing, Yandex.Disk, профиль Zen, kube/Helm/k9s, Xray/Hysteria, OAuth-данные и timer календаря, словари, пользовательские шрифты, MPV/Glow/yt-dlp, Obsidian, Documents, `/etc/hosts`, `/etc/fstab`, locale и инвентаризация установленных пакетов.

Системные файлы (NetworkManager, ModemManager, TLP, systemd units) сохраняются отдельным архивом и **не** разворачиваются автоматически: UUID и аппаратные настройки нельзя слепо переносить на другую установку.

## Пошаговый сценарий

**1. Бэкап на старой системе** (Ubuntu, Fedora или Omarchy):

```bash
chmod +x ./omarchy-bootstrap.sh
./omarchy-bootstrap.sh backup
cd ~/Yandex.Disk/system_configs/migration-HOST-YYYYMMDD-HHMMSS
sha256sum -c SHA256SUMS
```

GPG запросит пароль для шифрования. Пароль нигде не сохраняется. Не удаляй старую систему, пока бэкап не скопирован на второй носитель.

**2. Репетиция на свежей Omarchy**:

```bash
./omarchy-bootstrap.sh setup --dry-run
./omarchy-bootstrap.sh setup --thinkpad --dry-run   # для X1 Carbon Gen 9
```

**3. Установка и восстановление**:

```bash
# мини-ПК
./omarchy-bootstrap.sh all --from /path/to/migration-OLDHOST-YYYYMMDD-HHMMSS

# ThinkPad X1 Carbon Gen 9
./omarchy-bootstrap.sh all --from /path/to/migration-X1-YYYYMMDD-HHMMSS --thinkpad
```

**4. Google Calendar** (нужен браузер):

```bash
./omarchy-bootstrap.sh calendar-auth
```

Вручную в Google Cloud Console: OAuth consent screen, доступы `calendar.readonly` (и `calendar.events` для записи), **публикация приложения** (в режиме Testing токен живёт 7 дней) и OAuth client типа Desktop app.

**5. Выход из сессии, вход и проверка**:

```bash
./omarchy-bootstrap.sh verify
```

Перевход нужен для применения локали и группы `docker`.

## Идемпотентность

- Пакеты ставятся с `pacman --needed`; Stow вызывается с `--restow`.
- Блоки `/etc/hosts` и `/etc/fstab` управляются скриптом и не дублируются.
- Существующие плагины не клонируются повторно; `shell.json` правится только при изменении, перед этим создаётся копия `.bak.ДАТА`.
- Конфликтующие файлы dotfiles перемещаются в `~/.local/state/omarchy-bootstrap/stow-backups/`.
- Один и тот же бэкап повторно не восстанавливается без `--force`; заменяемые файлы уходят в `pre-restore-*`.

## Ограничения Omarchy

- Плагины Omarchy выполняются как код без песочницы в процессе оболочки; сторонние репозитории проверяй перед включением.
- Автоматическая установка плагинов надёжнее из запущенной графической сессии.
- OAuth и enrollment отпечатка (`fprintd-enroll`) остаются интерактивными.
- PAM для fingerprint, `mem_sleep_default=deep` и сброс WWAN после сна автоматически не применяются: нужна диагностика конкретного устройства.
- Проверь UUID профиля `Omarchy Cellular` в `~/.local/bin/wwan-toggle` после переустановки.
- Не переносятся: `dnf`/RPM, GNOME-настройки, Oh My Zsh/Powerlevel10k, история zsh, `rclone`, `tele`.

---

# Ubuntu 25.10 Automated Setup

Автоматизированный скрипт для настройки Ubuntu 25.10 с модульной установкой, гибкой конфигурацией и восстановлением системных параметров.

## Возможности

- Полная автоматизация конфигурирования свежей Ubuntu
- Режимы: подробный, тихий, проверка, только обновление
- Пропуск отдельных компонентов
- Восстановление конфигов из резервной копии через Yandex.Disk
- Цветной вывод и 16 этапов установки

## Устанавливаемые компоненты

**APT**: `curl`, `git`, `htop`, `btop`, `zip`, `unzip`, `net-tools`, `vim`, `neovim`, `zsh`, `powerline`, `fonts-powerline`, `lsd`, `ranger`, `tldr`, `tree-sitter-cli`, `ripgrep`, `bat`, `fd-find`, `tmux`, `zellij`, `powertop`, `lm-sensors`, `psensor`, `nvtop`, `intel-gpu-tools`, `mpv`, `vlc`, `python3`, `python3-neovim`, `postgresql-client`, `docker`, `apache2-utils`, `wireshark`, `stress`, `gnome-tweaks`, `gnome-shell-extensions`.

**Snap**: `telegram-desktop`, `multipass`, `musescore`, `k9s`.

**DevOps**: Docker и Docker Compose (с группой пользователя), kubectl v1.30.0, Helm с репозиториями, K9s.

**Shell**: Oh My Zsh, Powerlevel10k, `zsh-syntax-highlighting`, `zsh-autosuggestions`, AstroNvim.

**Дополнительно**: Yandex.Disk, расширения GNOME (Places Menu), восстановление SSH-ключей, Git-конфиг, Zen Browser (релизы GitHub, `.desktop`, алиас `zen`; модуль `zen_browser_install.sh`).

## Быстрый старт

1. Создай каталог конфигов:

```bash
mkdir -p ~/system_configs
```

2. Скопируй файлы через USB или Yandex.Disk:

```text
~/system_configs/
├── .bashrc
├── .zshrc
├── .p10k.zsh                    # опционально
├── fonts/                       # шрифты .ttf
├── ssh_keys_backup.zip
├── obsidian_1.8.9_amd64.deb     # опциональные DEB-пакеты
├── Yandex_Music_amd64_5.75.2.deb
├── Hiddify-Debian-x64.deb
└── zen_browser_install.sh
```

3. Сделай скрипт исполняемым и запусти (режим обязателен):

```bash
chmod +x ~/system_configs/ubuntu-setup-flags.sh
./ubuntu-setup-flags.sh -v    # подробный
./ubuntu-setup-flags.sh -q    # тихий
```

## Параметры

```text
-v, --verbose              Подробный режим
-q, --quiet                Тихий режим (ошибки и успех)
-h, --help                 Справка

--dry-run                  Проверка без установки
--only-update              Только обновить систему
--config-only              Только восстановить конфиги

--skip-docker              Пропустить Docker
--skip-kubernetes          Пропустить Kubernetes-инструменты
--skip-helm                Пропустить только Helm
--skip-packages            Пропустить все пакеты (apt/snap/deb)

-l, --log-file FILE        Сохранять логи в файл
```

## Примеры

```bash
./ubuntu-setup-flags.sh -q
./ubuntu-setup-flags.sh -v -l ~/setup.log
./ubuntu-setup-flags.sh -q --only-update
./ubuntu-setup-flags.sh -q --config-only
./ubuntu-setup-flags.sh --dry-run -q
./ubuntu-setup-flags.sh -q --skip-docker
./ubuntu-setup-flags.sh -v --skip-docker --skip-helm -l ~/setup.log
```

## 16 этапов

1. Обновление системы (`apt update/upgrade`, `snap refresh`)
2. Основные APT-пакеты
3. Docker
4. Kubernetes: kubectl, Helm, k9s
5. Yandex.Disk
6. Snap-пакеты
7. Шрифты из `fonts/`
8. Zsh, Oh My Zsh, Powerlevel10k, плагины
9. Восстановление `.bashrc`
10. NeoVim с AstroNvim
11. Расширения GNOME
12. DEB-пакеты: Obsidian, Yandex Music, Hiddify
13. SSH-ключи из `ssh_keys_backup.zip`
14. Конфигурация Git
15. Алиасы и функции
16. Финальные действия и проверки

## Резервная копия для Ubuntu-скрипта

```bash
mkdir -p ~/Yandex.Disk/system_configs/fonts
cp ~/.bashrc ~/.zshrc ~/Yandex.Disk/system_configs/
cp ~/.p10k.zsh ~/Yandex.Disk/system_configs/ 2>/dev/null || true
cp ~/.local/share/fonts/*.ttf ~/Yandex.Disk/system_configs/fonts/
cd ~/.ssh && zip -e -r ~/Yandex.Disk/system_configs/ssh_keys_backup.zip ./*
mv ~/Obsidian_*.deb ~/Yandex.Disk/system_configs/
mv ~/Yandex_Music_*.deb ~/Yandex.Disk/system_configs/
mv ~/Downloads/Hiddify-Debian-x64.deb ~/Yandex.Disk/system_configs/
```

Для переезда на Omarchy используй полноценный GPG-бэкап: `./omarchy-bootstrap.sh backup`.

## Требования и ограничения

- Ubuntu 25.10 или совместимая; обычный пользователь с `sudo`; интернет; около 20 GB; 30–60 минут.
- Не запускай от root; `-v` и `-q` взаимоисключающие; без режима выводится справка; `--dry-run` только показывает действия.

## Ошибки и повторный запуск

Скрипт пропускает установленные пакеты и выполненные этапы; конфиги копируются в `~/.config_backup_YYYYMMDD_HHMMSS`; ошибки логируются.

## После установки

```bash
sudo reboot            # применить группу Docker
p10k configure         # Powerlevel10k
yandex-disk setup      # первичная настройка Yandex.Disk
docker run hello-world # проверка Docker без sudo
```

Расширения GNOME ставятся через браузер с «GNOME Shell Integration».

## Структура

```text
ubuntu-setup-flags.sh      # основной скрипт Ubuntu
zen_browser_install.sh     # модуль Zen Browser
omarchy-bootstrap.sh       # backup/restore/bootstrap для Omarchy
```

---

# Общие правила безопасности

- Не коммить в Git: `.ssh`, `.gnupg`, токены, профили Syncthing и Yandex.Disk, `~/.zen`, конфиги Xray/WireGuard/AmneziaWG, `*.key`, `*.pem`, OAuth `client_secret.json`.
- Бэкап с приватными данными храни только зашифрованным (GPG) и проверяй `sha256sum -c SHA256SUMS`.
- Перед публикацией репозитория:

```bash
git grep -nEi 'private.?key|api.?key|api.?hash|token|password|endpoint|presharedkey' || true
git diff --check
git status --short
```

## Лицензия

Используйте свободно для личных и коммерческих проектов.

---

**Автор**: toxusa  
**Последнее обновление**: 2026-10-06  
**Версии**: Ubuntu-скрипт 1.1 (Advanced with Flags), Omarchy bootstrap 2026.10.06
