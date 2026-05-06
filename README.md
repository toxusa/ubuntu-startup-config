# Ubuntu 25.10 Automated Setup Script

Автоматизированный скрипт для полной настройки Ubuntu 25.10 с поддержкой модульной установки, гибкой конфигурации и восстановлением системных параметров.

## 🎯 Возможности

- **Полная автоматизация** системного конфигурирования на свежей Ubuntu
- **Гибкие режимы работы** (подробный, тихий, проверка, обновление-только)
- **Модульная установка** с возможностью пропускать отдельные компоненты
- **Восстановление конфигов** из резервной копии через Yandex.Disk
- **Цветной вывод логов** для удобного отслеживания прогресса
- **Обработка ошибок** с автоматическими повторами и резервными копиями
- **16-этапная установка** с возможностью начать с конкретного шага

## 📦 Устанавливаемые компоненты

### APT пакеты
- Системные утилиты: `curl`, `git`, `htop`, `btop`, `zip`, `unzip`, `net-tools`
- Текстовые редакторы: `vim`, `neovim`
- Shell: `zsh`, `powerline`, `fonts-powerline`
- Терминальные инструменты: `lsd`, `ranger`, `tldr`, `tree-sitter-cli`, `ripgrep`, `bat`, `fd-find`
- Мониторинг: `powertop`, `lm-sensors`, `psensor`, `nvtop`, `intel-gpu-tools`
- Медиа: `mpv`, `vlc`
- Разработка: `python3`, `python3-neovim`, `postgresql-client`
- DevOps: `docker`, `apache2-utils`
- Дополнительно: `wireshark`, `stress`, `gnome-tweaks`, `gnome-shell-extensions`

### Snap пакеты
- `telegram-desktop`
- `multipass`
- `musescore`
- `k9s`
- модуль `zen_browser_install.sh`, который устанавливает Zen Browser.

### Инструменты DevOps
- **Docker** & Docker Compose с настройкой группы пользователя
- **Kubernetes**: kubectl v1.30.0, Helm с репозиториями
- **K9s** - интерактивный CLI для Kubernetes

### Shell & Терминал
- **Oh My Zsh** с плагинами и темами
- **Powerlevel10k** - мощная тема для Zsh
- **Плагины**: zsh-syntax-highlighting, zsh-autosuggestions
- **AstroNvim** - готовый конфиг для Neovim

### Дополнительное ПО
- **Yandex.Disk** для синхронизации файлов
- **GNOME расширения** (Places Menu, и возможность установки других)
- **SSH ключи** - восстановление из резервной копии
- **Git конфиг** с предустановленными параметрами
- **Zen Browser** — установка из релизов GitHub с регистрацией .desktop и алиасом `zen`

## 🚀 Быстрый старт

### Подготовка

1. **Создайте директорию для конфигов** на свежей Ubuntu:
```bash
mkdir -p ~/system_configs
```

2. **Скопируйте необходимые файлы** через USB или Yandex.Disk:
```
~/system_configs/
├── .bashrc                      # конфиг для bash
├── .zshrc                       # конфиг для zsh
├── .p10k.zsh                    # конфиг Powerlevel10k (опционально)
├── fonts/                       # шрифты .ttf
├── ssh_keys_backup.zip          # бэкап SSH ключей
├── obsidian_1.8.9_amd64.deb    # опциональные DEB пакеты
├── Yandex_Music_amd64_5.75.2.deb
├── Hiddify-Debian-x64.deb
└── zen_browser_install.sh       # скрипт установки Zen Browser
```

3. **Сделайте скрипт исполняемым**:
```bash
chmod +x ~/system_configs/ubuntu-setup-flags.sh
```

### Запуск скрипта

**Обязательно** используйте один из режимов работы:

```bash
# Подробный режим (выводит все логи установки)
./ubuntu-setup-flags.sh -v

# Тихий режим (выводит только ошибки и успехи)
./ubuntu-setup-flags.sh -q
```

## 📋 Параметры запуска

### Основные параметры
```
-v, --verbose              Подробный режим установки
-q, --quiet                Тихий режим установки (только ошибки/успех)
-h, --help                 Показать справку и выход
```

### Специальные режимы
```
--dry-run                  Проверочный запуск без установки
--only-update              Только обновить систему
--config-only              Только восстановить конфиги
```

### Пропуск компонентов
```
--skip-docker              Пропустить установку Docker
--skip-kubernetes          Пропустить Kubernetes инструменты
--skip-helm                Пропустить только Helm
--skip-packages            Пропустить все пакеты (apt/snap/deb)
```

### Логирование
```
-l, --log-file FILE        Сохранять логи в файл
```

## 📝 Примеры использования

```bash
# Стандартная тихая установка
./ubuntu-setup-flags.sh -q

# Подробная установка с логированием
./ubuntu-setup-flags.sh -v -l ~/setup.log

# Только обновление системы
./ubuntu-setup-flags.sh -q --only-update

# Восстановление только конфигов
./ubuntu-setup-flags.sh -q --config-only

# Проверка перед установкой
./ubuntu-setup-flags.sh --dry-run -q

# Установка без Docker
./ubuntu-setup-flags.sh -q --skip-docker

# Установка без Kubernetes
./ubuntu-setup-flags.sh -q --skip-kubernetes

# Комбо: подробная установка без Helm и Docker, с логами
./ubuntu-setup-flags.sh -v --skip-docker --skip-helm -l ~/setup.log
```

## ⚙️ 16-этапная установка

Скрипт предоставляет интерактивное меню для выбора этапа запуска:

1. **Обновление системы** - `apt update`, `apt upgrade`, `snap refresh`
2. **Основные APT пакеты** - терминальные утилиты, редакторы, инструменты
3. **Docker** - установка и конфигурация группы пользователя
4. **Kubernetes** - kubectl, Helm, k9s
5. **Yandex.Disk** - облачная синхронизация
6. **Snap пакеты** - Telegram, Multipass, MuseScore
7. **Шрифты** - установка из `fonts/` директории
8. **Zsh и Oh My Zsh** - Powerlevel10k, плагины
9. **Восстановление .bashrc** - из резервной копии
10. **NeoVim с AstroNvim** - IDE для терминала
11. **GNOME расширения** - Places Menu и другие
12. **DEB пакеты** - Obsidian, Yandex Music, Hiddify
13. **SSH ключи** - восстановление из `ssh_keys_backup.zip`
14. **Конфигурация Git** - пользователь и credHelper
15. **Алиасы и функции** - полезные команды shell
16. **Финальные действия** - проверка Docker, настройка Yandex.Disk

## 🔧 Подготовка резервной копии

### Создание бэкапа конфигов
```bash
# 1. Создайте папку на Yandex.Disk
mkdir -p ~/Yandex.Disk/system_configs/fonts

# 2. Скопируйте конфиги shell
cp ~/.bashrc ~/Yandex.Disk/system_configs/
cp ~/.zshrc ~/Yandex.Disk/system_configs/
cp ~/.p10k.zsh ~/Yandex.Disk/system_configs/  # если есть

# 3. Скопируйте шрифты
cp ~/.local/share/fonts/*.ttf ~/Yandex.Disk/system_configs/fonts/

# 4. Создайте бэкап SSH ключей (зашифрованный архив)
cd ~/.ssh
zip -e -r ~/Yandex.Disk/system_configs/ssh_keys_backup.zip ./*

# 5. Переместите DEB пакеты
mv ~/Obsidian_*.deb ~/Yandex.Disk/system_configs/
mv ~/Yandex_Music_*.deb ~/Yandex.Disk/system_configs/
mv ~/Downloads/Hiddify-Debian-x64.deb ~/Yandex.Disk/system_configs/
```

## 📋 Требования

- **ОС**: Ubuntu 25.10 (или совместимая версия)
- **Пользователь**: обычный пользователь с sudo правами
- **Интернет**: требуется для загрузки пакетов
- **Место на диске**: ~20 GB для полной установки
- **Время**: 30-60 минут в зависимости от скорости интернета

## ❌ Ограничения

- **Не запускайте от root** - используйте обычного пользователя
- **Флаги `-v` и `-q` взаимоисключающие** - укажите только один
- **Требуется явно указать режим** - без флага получите справку
- **DRY-RUN не выполняет команды** - только показывает, что будет сделано

## 🐛 Обработка ошибок

- Скрипт автоматически пропускает уже установленные пакеты
- При повторном запуске пропускаются выполненные этапы
- Создаются резервные копии конфигов в `~/.config_backup_YYYYMMDD_HHMMSS`
- Все ошибки логируются с подробным контекстом

## 📌 Важные замечания

1. **После установки требуется перезагрузка**:
   ```bash
   sudo reboot
   ```
   Это необходимо для применения изменений группы Docker

2. **Powerlevel10k конфигурация**:
   ```bash
   p10k configure
   ```

3. **Yandex.Disk первоначальная настройка**:
   ```bash
   yandex-disk setup
   ```

4. **Docker работа без sudo** (после перезагрузки):
   ```bash
   docker run hello-world
   ```

5. **GNOME расширения** устанавливаются через браузер с расширением "GNOME Shell Integration"

## 📁 Структура проекта

```
ubuntu-setup-flags.sh
├── Функции логирования
├── Парсинг аргументов
├── 16 этапов установки
└── Финальная проверка компонентов

zen_browser_install.sh # модульная установка Zen Browser, вызывается из основного скрипта
```

## 🤝 Интеграция с DevOps

Скрипт полностью интегрирован с современным DevOps стеком:
- **Containerization**: Docker, Docker Compose
- **Orchestration**: Kubernetes (kubectl, Helm)
- **Monitoring**: K9s CLI, GPU tools
- **Configuration Management**: Git, SSH keys
- **Infrastructure as Code**: готовность к Ansible, Terraform

## 📞 Поддержка и обновления

Скрипт автоматически проверяет и обновляет все установленные компоненты при каждом запуске.

## 📜 Лицензия

Используйте свободно для личных и коммерческих проектов.

---

**Автор**: toxusa  
**Последнее обновление**: 2025-12-13  
**Версия**: 1.1 (Advanced with Flags)
