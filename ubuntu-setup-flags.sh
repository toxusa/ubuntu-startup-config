#!/bin/bash

################################################################################
# Ubuntu 25.10 Automated Setup Script (Advanced Version with Flags)
# Автоматизированная установка и настройка системы (Расширенная версия с флагами)
# Автор: toxusa
# Дата: 2025-11-14
################################################################################

# Основные пакеты: curl, htop, lsd, zsh, git, vim, neovim, ranger, tldr, docker, postgresql-client, mpv, tailspin, ptyxis и другие
# Snap пакеты: Firefox, Telegram Desktop, Thunderbird, Multipass, MuseScore
# GNOME расширения:
#     Media Controls
#     Places Menu
#     Privacy Menu
#     Top Bar Organizer (это то расширение, которое ты искал для перестановки элементов верхней панели!)
# Кастомизации:
#     Oh My Zsh с темой Powerlevel10k
#     Плагины: zsh-autosuggestions, zsh-syntax-highlighting
#     AstroNvim для Neovim
#     NVM для Node.js
#     Docker + Docker Compose
#     Yandex Browser и Yandex.Disk
#
# На свежей Ubuntu:
# mkdir -p ~/system_configs
# Скопируй через USB:
# Содержимое system_configs из Yandex.Disk → ~/system_configs
# Сделай скрипт исполняемым
# chmod +x ~/system_configs/ubuntu-setup.sh
# Запусти
# ~/system_configs/ubuntu-setup.sh -q    # или с нужным флагом
# Если что-то пошло не так, запусти еще раз - скрипт автоматически 
# пропустит уже установленное и исправит конфиги
#
# # Важные моменты
# Скрипт ожидает следующую структуру:
# ~/system_configs/
# ├── .bashrc
# ├── .zshrc
# ├── .p10k.zsh (если есть)
# ├── fonts/ (папка со шрифтами .ttf)
# ├── ssh_keys_backup.zip
# ├── obsidian_1.8.9_amd64.deb
# └── Yandex_Music_amd64_5.75.2.deb
#
#
# **Что нужно добавить в твой Yandex.Disk:**
#
# 1. Создай папку `system_configs` в корне Yandex.Disk
# 2. Скопируй туда актуальные конфиги:
#
# mkdir -p ~/Yandex.Disk/system_configs
# cp ~/.bashrc ~/Yandex.Disk/system_configs/
# cp ~/.zshrc ~/Yandex.Disk/system_configs/
# cp ~/.p10k.zsh ~/Yandex.Disk/system_configs/ # если есть
#
# 3. Создай бэкап SSH ключей:
# cd ~/.ssh
# zip -r ~/Yandex.Disk/system_configs/ssh_keys_backup.zip ./*
#
# 4. Скопируй шрифты:
# mkdir -p ~/system_configs/fonts
# cp ~/.local/share/fonts/*.ttf ~/Yandex.Disk/system_configs/fonts/
#
# 5. Перемести DEB пакеты:
# mv ~/Yandex.Disk/obsidian_*.deb ~/Yandex.Disk/system_configs/
# mv ~/Yandex.Disk/Yandex_Music_*.deb ~/Yandex.Disk/system_configs/
# mv ~/Yandex.Disk/VPN_manager/Hiddify-Debian-x64.deb ~/Yandex.Disk/system_configs/
#
# После запуска скрипта:
# Перезайди в систему (для применения Docker групп)
# Настрой Yandex.Disk: yandex-disk setup
# Запусти настройку Powerlevel10k: p10k configure
# Установи GNOME расширения через браузер с расширением "GNOME Shell Integration"
# Скрипт создаст бэкапы существующих конфигов перед их заменой и выведет цветные логи для отслеживания прогресса.

set -euo pipefail # Остановка при ошибках

# Цвета для вывода (определены до функций!)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переменные для режимов работы
VERBOSE_MODE=false
QUIET_MODE=false
DRY_RUN=false
ONLY_UPDATE=false
CONFIG_ONLY=false
SKIP_DOCKER=false
SKIP_KUBERNETES=false
SKIP_HELM=false
SKIP_PACKAGES=false
LOG_FILE=""

# Переменные
USER_HOME="$HOME"
CONFIG_DIR="$USER_HOME/system_configs"
BACKUP_DIR="$USER_HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
PACKAGES_FAILED=()

APT_PACKAGES=(
    apache2-utils
    apt-transport-https
    curl
    ca-certificates
    htop
    btop
    zip
    unzip
    lsd
    zsh
    powerline
    fonts-powerline
    git
    vim
    neovim
    python3
    python3-neovim
    python3-pip
    tree-sitter-cli
    ripgrep
    fastfetch
    ranger
    tldr
    postgresql-client
    powertop
    lm-sensors
    psensor
    nvtop
    intel-gpu-tools
    mpv
    vlc
    net-tools
    tailspin
    gnome-tweaks
    gnome-games
    gnome-shell-extensions
    xclip
    software-properties-common
    stress
    wireshark
)

SNAP_PACKAGES=(
    "telegram-desktop"
    "multipass"
    "musescore"
    "k9s"
)

STEPS=(
    "Начать с самого начала (Шаг 1: Обновление системы)"
    "Установка основных APT пакетов (Шаг 2)"
    "Установка Docker (Шаг 3)"
    "Установка Kubernetes инструментов (Шаг 4)"
    "Установка Yandex.Disk (Шаг 5)"
    "Установка Snap пакетов (Шаг 6)"
    "Установка шрифтов (Шаг 7)"
    "Настройка Zsh и Oh My Zsh (Шаг 8)"
    "Восстановление .bashrc (Шаг 9)"
    "Настройка NeoVim с AstroNvim (Шаг 10)"
    "Установка GNOME расширений (Шаг 11)"
    "Установка DEB пакетов (Шаг 12)"
    "Восстановление SSH ключей (Шаг 13)"
    "Настройка Git (Шаг 14)"
    "Создание полезных алиасов и функций (Шаг 15)"
    "Финальные действия (Шаг 16)"
    "Выход"
)

################################################################################
# Функции для логирования
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    if [ -n "$LOG_FILE" ]; then
        echo "[INFO] $1" >> "$LOG_FILE"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    if [ -n "$LOG_FILE" ]; then
        echo "[SUCCESS] $1" >> "$LOG_FILE"
    fi
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    if [ -n "$LOG_FILE" ]; then
        echo "[WARNING] $1" >> "$LOG_FILE"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    if [ -n "$LOG_FILE" ]; then
        echo "[ERROR] $1" >> "$LOG_FILE"
    fi
}

hashes() {
    echo -e "###############################################"
}

################################################################################
# Универсальная обертка для DRY_RUN
################################################################################

drun() {
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: $*"
    else
        eval "$@"
    fi
}

################################################################################
# Функция для вывода справки
################################################################################

show_help() {
    echo -e "
${GREEN}$(lsb_release -d | cut -f2) Automated Setup Script${NC}

${BLUE}Использование:${NC}
  ./ubuntu-setup.sh [ПАРАМЕТРЫ]

${BLUE}Основные параметры:${NC}
  -v, --verbose         Подробный режим (выводить все логи установки пакетов)
  -q, --quiet           Тихий режим установки (выводить только ошибки и успех)
                        По умолчанию требуется один из этих флагов
  -h, --help            Показать эту справку и выход

${BLUE}Специальные режимы:${NC}
  --dry-run             Проверочный запуск (показать что будет установлено, без установки)
  --only-update         Только обновить систему, ничего не устанавливать
  --config-only         Только восстановить конфиги, без установки пакетов

${BLUE}Пропуск компонентов:${NC}
  --skip-docker         Пропустить установку Docker
  --skip-kubernetes     Пропустить установку Kubernetes инструментов (kubectl, helm, k9s)
  --skip-helm           Пропустить установку только Helm (но установить kubectl)
  --skip-packages       Пропустить установку всех пакетов (apt, snap, deb)

${BLUE}Логирование:${NC}
  -l, --log-file FILE   Сохранять логи в указанный файл (дополнительно к консоли)

${BLUE}Примеры использования:${NC}
  ./ubuntu-setup.sh -q                          # Тихая установка
  ./ubuntu-setup.sh -v                          # Подробная установка
  ./ubuntu-setup.sh -q --skip-docker            # Тихая установка без Docker
  ./ubuntu-setup.sh -v --only-update            # Только обновить систему
  ./ubuntu-setup.sh -q --config-only            # Только восстановить конфиги
  ./ubuntu-setup.sh --dry-run -q                # Проверка перед установкой
  ./ubuntu-setup.sh -q -l ~/setup.log           # Запись в лог-файл

${BLUE}Примечание:${NC}
  • Всегда требуется явно указать режим (-v или -q)
  • Режимы -v и -q являются взаимоисключающими
  • Флаги --skip-* позволяют пропустить установку конкретных компонентов
  • Флаг -l записывает логи дополнительно в файл
  • При --only-update будет выполнено только обновление системы
  • При --config-only будут восстановлены только конфиги
  • При --dry-run никакие изменения не будут произведены

"
    exit 0
}

################################################################################
# Функция парсинга аргументов
################################################################################

parse_arguments() {
    if [ $# -eq 0 ]; then
        log_error "Ошибка: требуется указать флаг (-v или -q для режима установки)"
        echo ""
        show_help
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                if [ "$QUIET_MODE" = true ]; then
                    log_error "Ошибка: флаги -v и -q являются взаимоисключающими"
                    exit 1
                fi
                VERBOSE_MODE=true
                shift
                ;;
            -q|--quiet)
                if [ "$VERBOSE_MODE" = true ]; then
                    log_error "Ошибка: флаги -v и -q являются взаимоисключающими"
                    exit 1
                fi
                QUIET_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            --dry-run)
                DRY_RUN=true
                log_warning "РЕЖИМ ПРОВЕРКИ: Ничего не будет установлено!"
                shift
                ;;
            --only-update)
                ONLY_UPDATE=true
                log_info "Режим: Только обновление системы"
                shift
                ;;
            --config-only)
                CONFIG_ONLY=true
                log_info "Режим: Только восстановление конфигов"
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                log_warning "Docker будет пропущен"
                shift
                ;;
            --skip-kubernetes)
                SKIP_KUBERNETES=true
                log_warning "Kubernetes инструменты будут пропущены"
                shift
                ;;
            --skip-helm)
                SKIP_HELM=true
                log_warning "Helm будет пропущен"
                shift
                ;;
            --skip-packages)
                SKIP_PACKAGES=true
                log_warning "Все пакеты будут пропущены"
                shift
                ;;
            -l|--log-file)
                if [ $# -lt 2 ]; then
                    log_error "Ошибка: флаг -l требует аргумента (имя файла лога)"
                    exit 1
                fi
                LOG_FILE="$2"
                log_info "Логи будут сохранены в: $LOG_FILE"
                shift 2
                ;;
            *)
                log_error "Неизвестный параметр: $1"
                echo ""
                show_help
                ;;
        esac
    done

    # Проверка, что хотя бы один из режимов (-v или -q) выбран
    if [ "$VERBOSE_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
        log_error "Ошибка: требуется указать режим (-v для подробного или -q для тихого)"
        echo ""
        show_help
    fi

    # Предупреждение при смешивании --dry-run с -v
    if [ "$DRY_RUN" = true ] && [ "$VERBOSE_MODE" = true ]; then
        log_warning "DRY-RUN активен: подробный вывод установки команд отключён, так как они не выполняются."
    fi
}

################################################################################
# Функции для установки пакетов с проверкой
################################################################################

install_apt_package() {
    local package=$1
    local output_file
    output_file=$(mktemp)

    if [ "$DRY_RUN" = true ]; then
        if dpkg -s "$package" >/dev/null 2>&1; then
            rm -f "$output_file"
        else
            log_info "DRY-RUN: sudo apt install -y '$package'"
            rm -f "$output_file"
        fi
        return 0
    fi

    if dpkg -s "$package" >/dev/null 2>&1; then
        log_info "Пакет '$package' уже установлен, пропускаем."
        rm -f "$output_file"
        return 0
    fi

    log_info "Установка APT пакета: $package..."
    
    if [ "$VERBOSE_MODE" = true ]; then
        if sudo apt install -y "$package"; then
            log_success "APT пакет '$package' успешно установлен."
            return 0
        else
            log_error "Не удалось установить APT пакет: '$package'."
            PACKAGES_FAILED+=("$package")
            return 1
        fi
    else
        if sudo apt install -y "$package" > "$output_file" 2>&1; then
            log_success "APT пакет '$package' успешно установлен."
            rm -f "$output_file"
            return 0
        else
            log_error "Не удалось установить APT пакет: '$package'. Подробности ниже:"
            echo -e "${RED}"
            cat "$output_file"
            echo -e "${NC}"
            PACKAGES_FAILED+=("$package")
            rm -f "$output_file"
            return 1
        fi
    fi
}

install_snap_package() {
    local package=$1

    if [ "$DRY_RUN" = true ]; then
       if ! snap list 2>/dev/null | grep -q "^$package "; then
            log_info "DRY-RUN: sudo snap install '$package'"
       fi
        return 0
    fi
   
    if snap list 2>/dev/null | grep -q "^$package\b"; then
        log_info "Snap пакет '$package' уже установлен, пропускаем."
        return 0
    fi

    log_info "Установка Snap пакета: $package..."
    
    if [ "$VERBOSE_MODE" = true ]; then
        if sudo snap install "$package"; then
            log_success "Snap пакет '$package' успешно установлен."
            return 0
        else
            log_error "Не удалось установить Snap пакет: '$package'."
            PACKAGES_FAILED+=("snap:$package")
            return 1
        fi
    else
        local output_file
        output_file=$(mktemp)
        
        if sudo snap install "$package" > "$output_file" 2>&1; then
            log_success "Snap пакет '$package' успешно установлен."
            rm -f "$output_file"
            return 0
        else
            log_error "Не удалось установить Snap пакет: '$package'. Подробности ниже:"
            echo -e "${RED}"
            cat "$output_file"
            echo -e "${NC}"
            PACKAGES_FAILED+=("snap:$package")
            rm -f "$output_file"
            return 1
        fi
    fi
}

# Функция для установки DEB пакетов с "тихим" выводом и проверкой
install_deb_package() {
    local deb_filename=$1
    local package
    local output_file

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: sudo dpkg -i '$CONFIG_DIR/$deb_filename' || sudo apt install -f -y"
        return 0
    fi

    if [ ! -f "$CONFIG_DIR/$deb_filename" ]; then
        log_warning "DEB файл '$deb_filename' не найден в $CONFIG_DIR"
        return 1
    fi

    package=$(dpkg-deb --field "$CONFIG_DIR/$deb_filename" Package)

    if dpkg -s "$package" >/dev/null 2>&1; then
        log_info "DEB пакет '$package' уже установлен, пропускаем."
        return 0
    fi

    output_file=$(mktemp)
    log_info "Установка DEB пакета: $deb_filename..."

    if [ "$VERBOSE_MODE" = true ]; then
        if (sudo dpkg -i "$CONFIG_DIR/$deb_filename" || sudo apt install -f -y); then
            log_success "DEB пакет '$deb_filename' успешно установлен."
            rm -f "$output_file"
            return 0
        else
            log_error "Не удалось установить DEB пакет: '$deb_filename'."
            PACKAGES_FAILED+=("deb:$deb_filename")
            rm -f "$output_file"
            return 1
        fi
    else
        if (sudo dpkg -i "$CONFIG_DIR/$deb_filename" || sudo apt install -f -y) > "$output_file" 2>&1; then
            log_success "DEB пакет '$deb_filename' успешно установлен."
            rm -f "$output_file"
            return 0
        else
            log_error "Не удалось установить DEB пакет: '$deb_filename'. Подробности ниже:"
            echo -e "${RED}"
            cat "$output_file"
            echo -e "${NC}"
            PACKAGES_FAILED+=("deb:$deb_filename")
            rm -f "$output_file"
            return 1
        fi
    fi
}

# Функция для безопасного добавления строки в файл (идемпотентно)
append_to_file_once() {
    local file=$1
    local line=$2
    local description=${3:-""}
    
    if [ ! -f "$file" ]; then
        log_warning "Файл $file не существует, пропускаем добавление строки."
        return 1
    fi
    
    if grep -Fxq "$line" "$file" 2>/dev/null; then
        if [ -n "$description" ]; then
            log_info "$description - уже добавлено, пропускаем."
        fi
        return 0
    fi
    
    echo "" >> "$file"
    echo "$line" >> "$file"
    if [ -n "$description" ]; then
        log_success "$description - добавлено."
    fi
    return 0
}

check_docker_installation() {
    log_info "Проверка работоспособности Docker..."
    
    if ! sudo systemctl is-active --quiet docker; then
        log_warning "Служба Docker не запущена. Проверка невозможна."
        log_warning "Попробуйте запустить вручную: sudo systemctl start docker"
        return 1
    fi
    
    if docker run hello-world &> /dev/null; then
        log_success "Docker работает корректно от имени пользователя $USER."
        return 0
    else
        log_warning "Не удалось запустить Docker от имени $USER. Пробуем через sudo..."
        if sudo docker run hello-world &> /dev/null; then
            log_success "Docker работает корректно через sudo."
            log_warning "Чтобы использовать Docker без sudo, перезайдите в систему (logout/login)."
            return 0
        else
            log_error "КРИТИЧЕСКАЯ ОШИБКА: Docker установлен, но не может запустить контейнер даже через sudo."
            return 1
        fi
    fi
}

# Проверка прав root
if [ "$EUID" -eq 0 ]; then
    log_error "Не запускайте скрипт от root! Используйте обычного пользователя с sudo правами."
    exit 1
fi

# Парсим аргументы ПЕРЕД всем остальным
parse_arguments "$@"

log_info "Начало установки и настройки $(lsb_release -d | cut -f2)"
log_info "Домашняя директория: $USER_HOME"
log_info "Директория с конфигами и deb-пакетами: $CONFIG_DIR"

# Определяем, какой режим запуска
if [ "$ONLY_UPDATE" = true ]; then
    log_info "Активирован режим: Только обновление системы"
    START_STEP=1
elif [ "$CONFIG_ONLY" = true ]; then
    log_info "Активирован режим: Только восстановление конфигов"
    START_STEP=7  # Пропускаем обновление, пакеты, Docker и идем к конфигам
else
    # Показываем меню выбора шага
    log_info "Выберите номер шага, с которого нужно начать установку:"

    COLUMNS=1

    while true; do
        select choice in "${STEPS[@]}"; do
            if [[ -z "$choice" ]]; then
                log_warning "Неверный выбор. Пожалуйста, введите число от 1 до ${#STEPS[@]}."
                break
            fi

            if [ "$choice" == "Выход" ]; then
                log_info "Выход из скрипта."
                exit 0
            fi

            START_STEP=$REPLY
            log_info "Вы выбрали: $choice. Запускаем скрипт с шага $START_STEP."
            break 2
        done
    done
fi

################################################################################
# 1. Обновление системы
################################################################################
if [ $START_STEP -le 1 ]; then
    hashes
    log_info "Шаг 1: Обновление системы..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y && sudo apt-get autoremove -y && sudo snap refresh"
        log_success "Симуляция обновления завершена (ничего не выполнено)."
    elif [ "$VERBOSE_MODE" = true ]; then
        # Подробный режим - показываем весь вывод
        log_info "Запуск обновления в подробном режиме..."
        
        if sudo apt-get update -y && \
           sudo apt-get upgrade -y && \
           sudo apt-get dist-upgrade -y && \
           sudo apt-get autoremove -y && \
           sudo snap refresh; then
            log_success "Система успешно обновлена."
        else
            log_error "КРИТИЧЕСКАЯ ОШИБКА: Не удалось обновить систему. Выполнение скрипта прервано."
            exit 1
        fi
    else
        # Тихий режим - перенаправляем вывод в файл
        output_file=$(mktemp)

        if (
            sudo apt-get update -y && \
            sudo apt-get upgrade -y && \
            sudo apt-get dist-upgrade -y && \
            sudo apt-get autoremove -y && \
            sudo snap refresh
        ) > "$output_file" 2>&1; then
            log_success "Система успешно обновлена."
            rm -f "$output_file"
        else
            log_error "КРИТИЧЕСКАЯ ОШИБКА: Не удалось обновить систему. Выполнение скрипта прервано."
            log_error "Подробности ошибки ниже:"
            echo -e "${RED}"
            cat "$output_file"
            echo -e "${NC}"
            rm -f "$output_file"
            exit 1
        fi
    fi
fi

if [ "$ONLY_UPDATE" = true ]; then
    log_success "Режим --only-update: выполнено только обновление системы. Скрипт завершает работу."
    if [ -n "$LOG_FILE" ]; then
        log_info "Логи сохранены в: $LOG_FILE"
    fi
    exit 0
fi

################################################################################
# 2. Установка основных пакетов
################################################################################
# Защита: если ONLY_UPDATE, дальше не идем
if [ "$ONLY_UPDATE" = true ]; then
    exit 0
fi

if [ $START_STEP -le 2 ] && [ "$SKIP_PACKAGES" = false ]; then
    hashes
    log_info "Шаг 2: Установка основных пакетов..."

    for package in "${APT_PACKAGES[@]}"; do
        install_apt_package "$package" || true
    done

    log_success "Основные пакеты установлены"
fi

################################################################################
# 3. Установка Docker
################################################################################
if [ $START_STEP -le 3 ] && [ "$SKIP_DOCKER" = false ]; then
    hashes
    log_info "Шаг 3: Установка Docker..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка Docker и добавление пользователя в группу docker"
    elif ! command -v docker &> /dev/null; then
        log_info "Docker не установлен, начинаем установку..."
        
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
            sudo apt remove -y "$pkg" 2>/dev/null || true
        done

        log_info "Добавление ключа GPG Docker..."
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        
        log_info "Добавление репозитория Docker..."
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt update
        install_apt_package "docker-ce" || true
        install_apt_package "docker-ce-cli" || true
        install_apt_package "containerd.io" || true
        install_apt_package "docker-buildx-plugin" || true
        install_apt_package "docker-compose-plugin" || true

        log_success "Docker установлен"
    else
        log_info "Docker уже установлен"
    fi
    if ! id -Gn "$USER" | grep -q docker; then
            log_info "Добавление пользователя в группу docker..."
            drun "sudo usermod -aG docker '$USER'"
            newgrp docker
            log_info "Пользователь добавлен в группу docker"
        else
            log_info "Пользователь уже в группе docker"
    fi

fi

################################################################################
# 4. Установка Kubernetes инструментов
################################################################################
if [ $START_STEP -le 4 ] && [ "$SKIP_KUBERNETES" = false ]; then
    hashes
    log_info "Шаг 4: Установка Kubernetes инструментов..."

    # --- Установка kubectl ---
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка kubectl v1.30.0"
    elif ! command -v kubectl &> /dev/null; then
        log_info "Установка kubectl..."
        drun "wget https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
        drun "sudo mv kubectl /usr/local/bin/"
        drun "sudo chmod +x /usr/local/bin/kubectl"

        # По умолчанию используется команда ниже, но может не заработать в ru CDN
        # curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        # sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        # rm kubectl
        log_success "kubectl установлен."
    else
        log_info "kubectl уже установлен."
    fi

    # --- Установка Helm ---
    if [ "$SKIP_HELM" = false ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: Установка Helm"
        elif ! command -v helm &> /dev/null; then
            log_info "Установка Helm..."
            drun "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
            log_success "Helm установлен."
        else
            log_info "Helm уже установлен."
        fi

        if command -v helm &> /dev/null; then
            if [ "$DRY_RUN" = true ]; then
                log_info "DRY-RUN: Добавление Helm репозитория stable"
            else
                if ! helm repo list 2>/dev/null | grep -q "stable"; then
                    log_info "Добавление репозитория Helm stable..."
                    drun "helm repo add stable https://charts.helm.sh/stable"
                fi
                helm repo update
                
                if [ -f "$USER_HOME/.zshrc" ]; then
                    append_to_file_once "$USER_HOME/.zshrc" "source <(helm completion zsh)" "Автодополнение Helm для zsh"
                fi
            fi
        fi
    fi
fi


################################################################################
# 5. Установка Yandex.Disk
################################################################################
if [ $START_STEP -le 5 ]; then
    hashes
    log_info "Шаг 5: Установка Yandex.Disk..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка Yandex.Disk"
    elif ! command -v yandex-disk &> /dev/null; then
        echo "deb http://repo.yandex.ru/yandex-disk/deb/ stable main" | sudo tee -a /etc/apt/sources.list.d/yandex-disk.list > /dev/null
        # Метод ниже устарел
        # wget http://repo.yandex.ru/yandex-disk/YANDEX-DISK-KEY.GPG -O- | sudo apt-key add -

        # Современный и безопасный метод добавления ключа
        curl -fsSL http://repo.yandex.ru/yandex-disk/YANDEX-DISK-KEY.GPG | sudo gpg --dearmor -o /usr/share/keyrings/yandex-disk.gpg
        # Добавление репозитория с указанием на ключ
        echo "deb [signed-by=/usr/share/keyrings/yandex-disk.gpg] http://repo.yandex.ru/yandex-disk/deb/ stable main" | sudo tee /etc/apt/sources.list.d/yandex-disk.list > /dev/null
        
        sudo apt update
        sudo apt install -y yandex-disk
        log_success "Yandex.Disk установлен"
        log_warning "Не забудьте настроить Yandex.Disk: yandex-disk setup"
    else
        log_info "Yandex.Disk уже установлен"
    fi
fi

################################################################################
# 6. Установка Snap пакетов
################################################################################
if [ $START_STEP -le 6 ] && [ "$SKIP_PACKAGES" = false ]; then
    hashes
    log_info "Шаг 6: Установка Snap пакетов..."

    for package in "${SNAP_PACKAGES[@]}"; do
        install_snap_package "$package" || true
    done

    log_success "Snap пакеты установлены"
fi

################################################################################
# 7. Установка шрифтов
################################################################################
if [ $START_STEP -le 7 ]; then
    hashes
    log_info "Шаг 7: Установка шрифтов..."

    mkdir -p "$USER_HOME/.local/share/fonts"

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Копирование шрифтов и обновление кэша"
    elif [ -d "$CONFIG_DIR/fonts" ]; then
        log_info "Копирование шрифтов из конфиг-каталога..."
        drun "cp -r '$CONFIG_DIR/fonts/'*.ttf '$USER_HOME/.local/share/fonts/' 2>/dev/null || true"
        drun "sudo cp '$USER_HOME/.local/share/fonts/'*.ttf /usr/share/fonts/ 2>/dev/null || true"
    else
        log_warning "Шрифты не найдены в '$CONFIG_DIR'. Пропускаем установку шрифтов."
    fi

    if [ -d "$USER_HOME/.local/share/fonts" ]; then
        if [ "$DRY_RUN" = false ]; then
            fc-cache -f -v "$USER_HOME/.local/share/fonts"
        fi
    fi
    log_success "Шрифты установлены"
fi

################################################################################
# 8. Настройка Zsh и Oh My Zsh
################################################################################
if [ $START_STEP -le 8 ]; then
    hashes
    log_info "Шаг 8: Настройка Zsh..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка Oh My Zsh, Powerlevel10k и плагинов"
    else
        if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
            log_info "Установка Oh My Zsh..."
            drun "git clone https://github.com/robbyrussell/oh-my-zsh.git '$USER_HOME/.oh-my-zsh'"
            drun "cp '$USER_HOME/.oh-my-zsh/templates/zshrc.zsh-template' '$USER_HOME/.zshrc'"
        else
            log_info "Oh My Zsh уже установлен"
        fi

        if [ ! -d "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
            log_info "Установка Powerlevel10k..."
            drun "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
        else
            log_info "Powerlevel10k уже установлен"
        fi

        if [ ! -d "$USER_HOME/.zsh-syntax-highlighting" ]; then
            log_info "Установка zsh-syntax-highlighting..."
            drun "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git '$USER_HOME/.zsh-syntax-highlighting' --depth 1"
        else
            log_info "zsh-syntax-highlighting уже установлен"
        fi

        if [ ! -d "$USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
            log_info "Установка zsh-autosuggestions..."
            drun "git clone https://github.com/zsh-users/zsh-autosuggestions '$USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions'"
        else
            log_info "zsh-autosuggestions уже установлен"
        fi
    fi

    if [ -f "$CONFIG_DIR/.zshrc" ]; then
        log_info "Восстановление .zshrc из конфиг-каталога..."
        drun "cp '$CONFIG_DIR/.zshrc' '$USER_HOME/.zshrc'"
    else
        if [ "$DRY_RUN" = false ]; then
            log_warning ".zshrc не найден в конфиг-каталоге. Используется стандартный шаблон."
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Изменение оболочки на zsh"
    elif ! grep -q "^$USER:.*:$(which zsh)$" /etc/passwd; then
        log_info "Изменение оболочки по умолчанию на zsh..."
        drun "chsh -s /bin/zsh"
        log_success "Оболочка изменена на zsh"
    else
        log_info "Zsh уже является оболочкой по умолчанию"
    fi

    log_success "Zsh настроен"
fi

################################################################################
# 9. Восстановление bashrc
################################################################################
if [ $START_STEP -le 9 ]; then
    hashes
    log_info "Шаг 9: Восстановление .bashrc..."

    if [ -f "$CONFIG_DIR/.bashrc" ]; then
        log_info "Восстановление .bashrc из конфиг-каталога..."
        drun "cp '$CONFIG_DIR/.bashrc' '$USER_HOME/.bashrc'"
        log_success ".bashrc восстановлен"
    else
        log_warning ".bashrc не найден в конфиг-каталоге"
    fi
fi

################################################################################
# 10. Установка NeoVim с AstroNvim
################################################################################
if [ $START_STEP -le 10 ]; then
    hashes
    log_info "Шаг 10: Настройка NeoVim с AstroNvim..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка AstroNvim"
    elif [ ! -d "$USER_HOME/.config/nvim" ]; then
        log_info "Установка AstroNvim..."
        mkdir -p "$BACKUP_DIR"
        drun "[ -d '$USER_HOME/.config/nvim' ] && mv '$USER_HOME/.config/nvim' '$BACKUP_DIR/nvim.bak'"
        drun "[ -d '$USER_HOME/.local/share/nvim' ] && mv '$USER_HOME/.local/share/nvim' '$BACKUP_DIR/nvim_share.bak'"
        drun "[ -d '$USER_HOME/.local/state/nvim' ] && mv '$USER_HOME/.local/state/nvim' '$BACKUP_DIR/nvim_state.bak'"
        drun "[ -d '$USER_HOME/.cache/nvim' ] && mv '$USER_HOME/.cache/nvim' '$BACKUP_DIR/nvim_cache.bak'"

        if [ "$DRY_RUN" = false ]; then
            if git clone --depth 1 https://github.com/AstroNvim/template "$USER_HOME/.config/nvim"; then
                rm -rf "$USER_HOME/.config/nvim/.git"
                log_success "AstroNvim установлен"
            else
                log_error "Не удалось установить AstroNvim"
            fi
        fi
    else
        log_info "AstroNvim уже установлен"
    fi
fi


################################################################################
# 11. Установка GNOME расширений
################################################################################
if [ $START_STEP -le 11 ]; then
    hashes
    log_info "Шаг 11: Установка GNOME расширений..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Активирование Places Menu"
    elif command -v gnome-extensions &> /dev/null; then
        drun "gnome-extensions enable places-menu@gnome-shell-extensions.gcampax.github.com 2>/dev/null || true"
        log_info "Places Menu активирован (если доступен)"
    fi

    log_warning "Для установки других расширений:"
    log_warning "  - Media Controls: https://extensions.gnome.org/extension/4470/media-controls/"
    log_warning "  - Privacy Menu: https://extensions.gnome.org/extension/4491/privacy-menu/"
    log_warning "  - Top Bar Organizer: https://extensions.gnome.org/extension/4356/top-bar-organizer/"
    log_info "Используйте Firefox/Chrome с расширением GNOME Shell Integration"
fi

################################################################################
# 12. Установка DEB пакетов
################################################################################
if [ $START_STEP -le 12 ] && [ "$SKIP_PACKAGES" = false ]; then
    hashes
    log_info "Шаг 12: Установка DEB пакетов из директории '$CONFIG_DIR'"

    if [ -d "$CONFIG_DIR" ]; then
        for package in "$CONFIG_DIR"/*.deb; do
            if [ -f "$package" ]; then
                deb_filename=$(basename "$package")
                install_deb_package "$deb_filename" || true
            fi
        done
    else
        log_warning "Конфиг-каталог $CONFIG_DIR не найден"
    fi
fi

################################################################################
# 13. Восстановление SSH ключей
################################################################################
if [ $START_STEP -le 13 ]; then
    hashes
    log_info "Шаг 13: Восстановление SSH ключей..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Восстановление SSH ключей из бэкапа"
    elif [ -f "$CONFIG_DIR/ssh_keys_backup.zip" ]; then
        mkdir -p "$USER_HOME/.ssh"
        # Если в .ssh уже есть файлы, сделаем бэкап
        if [ "$(ls -A $USER_HOME/.ssh)" ]; then
            log_warning "В директории .ssh уже есть файлы. Создаем бэкап в $BACKUP_DIR/ssh_backup"
            drun "cp -r $USER_HOME/.ssh $BACKUP_DIR/ssh_backup"
        fi
        drun "unzip -o '$CONFIG_DIR/ssh_keys_backup.zip' -d '$USER_HOME/.ssh/'"
        drun "chmod 700 '$USER_HOME/.ssh'"
        drun "chmod 600 '$USER_HOME/.ssh/'*"
        log_success "SSH ключи восстановлены"
    else
        log_warning "Бэкап SSH ключей не найден"
    fi
fi

################################################################################
# 14. Настройка Git
################################################################################
if [ $START_STEP -le 14 ]; then
    hashes
    log_info "Шаг 14: Настройка Git..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Настройка Git конфигурации"
    elif ! git config --global user.email &>/dev/null; then
        drun "git config --global user.email 'toxusa@yandex.ru'"
        drun "git config --global user.name 'toxusa'"
        drun "git config --global credential.helper 'cache --timeout=3600'"
        log_success "Git настроен"
    else
        log_info "Git уже настроен"
    fi
fi

################################################################################
# 15. Создание полезных алиасов и функций
################################################################################
if [ $START_STEP -le 15 ]; then
    hashes
    log_info "Шаг 15: Настройка системных алиасов..."

    # Алиасы уже включены в .zshrc, который будет восстановлен

    # Восстановление p10k 
    if [ -f "$CONFIG_DIR/.p10k.zsh" ]; then
        log_info "Восстановление .p10k.zsh..."
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: cp '$CONFIG_DIR/.p10k.zsh' '$USER_HOME/.p10k.zsh'"
        else
            drun "cp '$CONFIG_DIR/.p10k.zsh' '$USER_HOME/.p10k.zsh'"
        fi
    else
        log_info "Запуск настройки Powerlevel10k..."
        log_info "После перезагрузки выполните: p10k configure"
    fi
fi

# --- Установка k9s ---
# Закомментирован, потому что устанавливаем в другом месте автоматически через snap
# if ! command -v k9s &> /dev/null; then
#     log_info "Установка k9s..."
#     curl -sS https://webinstall.dev/k9s | bash
#     log_success "k9s установлен."
# else
#     log_info "k9s уже установлен."
# fi
#
# # --- Добавление ~/.local/bin в PATH для zsh (для k9s) ---
# if [ -f "$USER_HOME/.zshrc" ]; then
#     if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$USER_HOME/.zshrc"; then
#         log_info "Добавление ~/.local/bin в PATH для .zshrc..."
#         echo '' >> "$USER_HOME/.zshrc"
#         echo '# Add ~/.local/bin to PATH for user-installed binaries (like k9s)' >> "$USER_HOME/.zshrc"
#         echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.zshrc"
#     fi
# fi

################################################################################
# 5. Установка Yandex Browser
################################################################################
# log_info "Шаг 5: Установка Yandex Browser..."
#
# if ! command -v yandex-browser-stable &> /dev/null; then
#     curl -fsSL https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG | sudo gpg --dearmor | sudo tee /usr/share/keyrings/yandex.gpg > /dev/null
#     echo "deb [arch=amd64 signed-by=/usr/share/keyrings/yandex.gpg] http://repo.yandex.ru/yandex-browser/deb stable main" | sudo tee /etc/apt/sources.list.d/yandex-stable.list
#     sudo apt update
#     sudo apt install -y yandex-browser-stable
#     log_success "Yandex Browser установлен"
# else
#     log_info "Yandex Browser уже установлен"
# fi


################################################################################
# 11. Установка NVM (Node Version Manager)
################################################################################
# log_info "Шаг 11: Установка NVM..."
#
# if [ ! -d "$USER_HOME/.nvm" ]; then
#     log_info "Установка NVM..."
#     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
#     
#     export NVM_DIR="$USER_HOME/.nvm"
#     [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
#     
#     log_success "NVM установлен"
# else
#     log_info "NVM уже установлен"
# fi


################################################################################
# Финальные действия
################################################################################
if [ $START_STEP -le 16 ]; then
    log_success "============================================"
    log_success "Установка завершена!"
    log_success "============================================"
    echo ""

    if [ ${#PACKAGES_FAILED[@]} -gt 0 ]; then
        log_warning "Не удалось установить следующие пакеты:"
        for failed_pkg in "${PACKAGES_FAILED[@]}"; do
            echo -e "  ${YELLOW}- $failed_pkg${NC}"
        done
        echo ""
    fi

    log_info "Важные шаги после установки:"
    echo ""
    echo "1. Перезайдите в систему для применения изменений групп (Docker)"
    echo "2. Запустите Powerlevel10k конфигурацию: p10k configure"
    echo "3. Установите GNOME расширения через браузер"
    echo "4. Проверьте SSH ключи: ls -la ~/.ssh/"
    echo "5. Проверьте Docker: docker run hello-world"
    echo ""

    if [ "$DRY_RUN" = false ]; then
        log_info "Проверка и настройка ключевых компонентов системы..."
        check_docker_installation

        if command -v yandex-disk &> /dev/null; then
            if [ -f "$USER_HOME/.config/yandex-disk/config.cfg" ]; then
                log_info "Yandex.Disk уже настроен. Пропускаем."
            else
                read -p "Хотите выполнить первоначальную настройку Yandex.Disk сейчас? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    yandex-disk setup
                    log_success "Настройка Yandex.Disk завершена."
                else
                    log_info "Настройка Yandex.Disk пропущена. Вы можете выполнить 'yandex-disk setup' позже."
                fi
            fi
        fi
    fi

    log_info "Бэкапы старых конфигов сохранены в: $BACKUP_DIR"
    echo ""
    log_warning "Рекомендуется перезагрузить систему: sudo reboot"
    
    if [ -n "$LOG_FILE" ]; then
        log_info "Логи сохранены в: $LOG_FILE"
    fi
fi
