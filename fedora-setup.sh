#!/bin/bash

################################################################################
# Fedora 44 Automated Setup Script
# Автоматизированная установка и настройка системы
# Автор: toxusa
# Устройство: Lenovo ThinkPad X1 Carbon Gen 9
# Дата: 2026-05-11
################################################################################

# Пакеты DNF:
# curl, htop, btop, lsd, zsh, git, vim, neovim, ranger, tealdeer, docker,
# postgresql, mpv, vlc, alacritty, wireshark, stress, stow, powertop, и другие
# Пакеты Flatpak (Flathub):
# Telegram Desktop, MuseScore, Obsidian, Zen Browser, Extension Manager
# Кастомизации:
# Oh My Zsh с темой Powerlevel10k
# Плагины: zsh-autosuggestions, zsh-syntax-highlighting
# AstroNvim для Neovim
# Alacritty терминал + Zellij мультиплексор
# Docker + Docker Compose
# kubectl + Helm + k9s
# Yandex.Disk (RPM с --nodigest)
# FCC-разблокировка WWAN модема (Quectel EM120R-GL)
# Сканер отпечатков пальцев (Synaptics Prometheus)

# На свежей Fedora 44:
# mkdir -p ~/system_configs
# Скопируй через USB:
# Содержимое system_configs из Yandex.Disk → ~/system_configs
# Сделай скрипт исполняемым
# chmod +x ~/system_configs/fedora-setup.sh
# Запусти
# ~/system_configs/fedora-setup.sh -q   # или с нужным флагом

# Структура ~/system_configs/:
# ├── .bashrc
# ├── .zshrc
# ├── .p10k.zsh (если есть)
# ├── fonts/                (папка со шрифтами .ttf)
# ├── ssh_keys_backup.zip
# ├── alacritty.toml
# ├── alacritty-theme       (скрипт смены тем)
# └── zellij                (бинарник Zellij, опционально)

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Режимы работы
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

# Переменные окружения
USER_HOME="$HOME"
CONFIG_DIR="$USER_HOME/system_configs"
BACKUP_DIR="$USER_HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
PACKAGES_FAILED=()

# Основные DNF пакеты
# Примечания по отличиям от Ubuntu:
#   apache2-utils          → httpd-tools
#   python3-neovim         → python3-pynvim
#   lm-sensors             → lm_sensors
#   postgresql-client      → postgresql
#   fonts-powerline        → powerline-fonts
#   apt-transport-https    → НЕ НУЖЕН в Fedora
#   software-properties-common → НЕ НУЖЕН в Fedora
#   ca-certificates        → ca-certificates (то же имя)
#   fd-find                → fd-find (то же имя)
#   bat                    → bat (то же имя)
DNF_PACKAGES=(
httpd-tools
curl
ca-certificates
htop
btop
zip
unzip
lsd
bat
fd-find
zsh
powerline
powerline-fonts
git
vim
neovim
python3
python3-pynvim
python3-pip
ripgrep
fastfetch
ranger
tealdeer
postgresql
powertop
lm_sensors
nvtop
intel-gpu-tools
mpv
vlc
net-tools
gnome-tweaks
gnome-shell-extension-appindicator
gnome-extensions-app
xclip
stress
wireshark
stow
alacritty
k9s
translate-shell
sdcv
)

# Flatpak пакеты (вместо Snap на Fedora)
FLATPAK_PACKAGES=(
"org.telegram.desktop"
"org.musescore.MuseScore"
"md.obsidian.Obsidian"
"app.zen_browser.zen"
"com.mattjakeman.ExtensionManager"
)

STEPS=(
"Начать с самого начала (Шаг 1: Обновление системы)"
"Установка основных DNF пакетов (Шаг 2)"
"Установка Docker (Шаг 3)"
"Установка Kubernetes инструментов (Шаг 4)"
"Установка Yandex.Disk (Шаг 5)"
"Установка Flatpak пакетов (Шаг 6)"
"Установка AmneziaWG + vpn-awg (Шаг 7)"
"Установка шрифтов (Шаг 8)"
"Настройка Zsh и Oh My Zsh (Шаг 9)"
"Восстановление .bashrc (Шаг 10)"
"Настройка NeoVim с AstroNvim (Шаг 11)"
"Настройка Alacritty и Zellij (Шаг 12)"
"Настройка GNOME (Шаг 13)"
"Настройка Yandex Browser (Шаг 14)"
"Восстановление SSH ключей (Шаг 15)"
"Настройка Git (Шаг 16)"
"Настройка алиасов и p10k (Шаг 17)"
"Настройка аппаратных компонентов ThinkPad X1 Carbon Gen 9 (Шаг 18)"
"Финальные действия (Шаг 19)"
"Выход"
)

################################################################################
# Функции для логирования
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    if [ -n "$LOG_FILE" ]; then echo "[INFO] $1" >> "$LOG_FILE"; fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    if [ -n "$LOG_FILE" ]; then echo "[SUCCESS] $1" >> "$LOG_FILE"; fi
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    if [ -n "$LOG_FILE" ]; then echo "[WARNING] $1" >> "$LOG_FILE"; fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    if [ -n "$LOG_FILE" ]; then echo "[ERROR] $1" >> "$LOG_FILE"; fi
}

hashes() {
    echo -e "###############################################"
}

################################################################################
# Универсальная обёртка для DRY_RUN
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
${GREEN}Fedora 44 Automated Setup Script (ThinkPad X1 Carbon Gen 9)${NC}

${BLUE}Использование:${NC}
./fedora-setup.sh [ПАРАМЕТРЫ]

${BLUE}Основные параметры:${NC}
-v, --verbose   Подробный режим (выводить все логи установки пакетов)
-q, --quiet     Тихий режим установки (выводить только ошибки и успех)
-h, --help      Показать эту справку и выход

${BLUE}Специальные режимы:${NC}
--dry-run       Проверочный запуск (показать что будет установлено, без установки)
--only-update   Только обновить систему, ничего не устанавливать
--config-only   Только восстановить конфиги, без установки пакетов

${BLUE}Пропуск компонентов:${NC}
--skip-docker       Пропустить установку Docker
--skip-kubernetes   Пропустить установку Kubernetes инструментов
--skip-helm         Пропустить установку Helm
--skip-packages     Пропустить установку всех пакетов

${BLUE}Логирование:${NC}
-l, --log-file FILE   Сохранять логи в указанный файл

${BLUE}Примеры:${NC}
./fedora-setup.sh -q
./fedora-setup.sh -v
./fedora-setup.sh -q --skip-docker
./fedora-setup.sh -v --only-update
./fedora-setup.sh -q --config-only
./fedora-setup.sh --dry-run -q
./fedora-setup.sh -q -l ~/setup.log
"
    exit 0
}

################################################################################
# Парсинг аргументов
################################################################################

parse_arguments() {
    if [ $# -eq 0 ]; then
        log_error "Требуется указать флаг (-v или -q для режима установки)"
        echo ""
        show_help
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                if [ "$QUIET_MODE" = true ]; then
                    log_error "Флаги -v и -q являются взаимоисключающими"
                    exit 1
                fi
                VERBOSE_MODE=true
                shift
                ;;
            -q|--quiet)
                if [ "$VERBOSE_MODE" = true ]; then
                    log_error "Флаги -v и -q являются взаимоисключающими"
                    exit 1
                fi
                QUIET_MODE=true
                shift
                ;;
            -h|--help) show_help ;;
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
                    log_error "Флаг -l требует аргумента (имя файла лога)"
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

    if [ "$VERBOSE_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
        log_error "Требуется указать режим (-v или -q)"
        echo ""
        show_help
    fi

    if [ "$DRY_RUN" = true ] && [ "$VERBOSE_MODE" = true ]; then
        log_warning "DRY-RUN активен: подробный вывод отключён."
    fi
}

################################################################################
# Функции установки пакетов
################################################################################

install_dnf_package() {
    local package=$1
    local output_file
    output_file=$(mktemp)

    if [ "$DRY_RUN" = true ]; then
        if rpm -q "$package" &>/dev/null; then
            rm -f "$output_file"
        else
            log_info "DRY-RUN: sudo dnf install -y '$package'"
            rm -f "$output_file"
        fi
        return 0
    fi

    if rpm -q "$package" &>/dev/null; then
        log_info "Пакет '$package' уже установлен, пропускаем."
        rm -f "$output_file"
        return 0
    fi

    log_info "Установка DNF пакета: $package..."

    if [ "$VERBOSE_MODE" = true ]; then
        if sudo dnf install -y "$package"; then
            log_success "DNF пакет '$package' успешно установлен."
            return 0
        else
            log_error "Не удалось установить DNF пакет: '$package'."
            PACKAGES_FAILED+=("$package")
            return 1
        fi
    else
        if sudo dnf install -y "$package" > "$output_file" 2>&1; then
            log_success "DNF пакет '$package' успешно установлен."
            rm -f "$output_file"
            return 0
        else
            log_error "Не удалось установить DNF пакет: '$package'. Подробности ниже:"
            echo -e "${RED}"
            cat "$output_file"
            echo -e "${NC}"
            PACKAGES_FAILED+=("$package")
            rm -f "$output_file"
            return 1
        fi
    fi
}

install_flatpak_package() {
    local package=$1

    if [ "$DRY_RUN" = true ]; then
        if ! flatpak list 2>/dev/null | grep -q "$package"; then
            log_info "DRY-RUN: flatpak install -y flathub '$package'"
        fi
        return 0
    fi

    if flatpak list 2>/dev/null | grep -q "$package"; then
        log_info "Flatpak пакет '$package' уже установлен, пропускаем."
        return 0
    fi

    log_info "Установка Flatpak пакета: $package..."
    local output_file
    output_file=$(mktemp)

    if [ "$VERBOSE_MODE" = true ]; then
        if flatpak install -y flathub "$package"; then
            log_success "Flatpak пакет '$package' успешно установлен."
            return 0
        else
            log_error "Не удалось установить Flatpak пакет: '$package'."
            PACKAGES_FAILED+=("flatpak:$package")
            return 1
        fi
    else
        if flatpak install -y flathub "$package" > "$output_file" 2>&1; then
            log_success "Flatpak пакет '$package' успешно установлен."
            rm -f "$output_file"
            return 0
        else
            log_error "Не удалось установить Flatpak пакет: '$package'. Подробности ниже:"
            echo -e "${RED}"
            cat "$output_file"
            echo -e "${NC}"
            PACKAGES_FAILED+=("flatpak:$package")
            rm -f "$output_file"
            return 1
        fi
    fi
}

append_to_file_once() {
    local file=$1
    local line=$2
    local description=${3:-""}

    if [ ! -f "$file" ]; then
        log_warning "Файл $file не существует, пропускаем."
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
        log_warning "Служба Docker не запущена."
        log_warning "Попробуйте запустить вручную: sudo systemctl start docker"
        return 1
    fi

    if docker run hello-world &>/dev/null; then
        log_success "Docker работает корректно от имени пользователя $USER."
        return 0
    else
        log_warning "Не удалось запустить Docker от имени $USER. Пробуем через sudo..."
        if sudo docker run hello-world &>/dev/null; then
            log_success "Docker работает через sudo."
            log_warning "Для использования без sudo — перезайдите в систему (logout/login)."
            return 0
        else
            log_error "Docker установлен, но не может запустить контейнер."
            return 1
        fi
    fi
}

################################################################################
# Проверка прав root
################################################################################

if [ "$EUID" -eq 0 ]; then
    log_error "Не запускайте скрипт от root! Используйте обычного пользователя с sudo правами."
    exit 1
fi

parse_arguments "$@"

log_info "Начало установки и настройки Fedora Linux 44 (ThinkPad X1 Carbon Gen 9)"
log_info "Домашняя директория: $USER_HOME"
log_info "Директория с конфигами: $CONFIG_DIR"

if [ "$ONLY_UPDATE" = true ]; then
    log_info "Активирован режим: Только обновление системы"
    START_STEP=1
elif [ "$CONFIG_ONLY" = true ]; then
    log_info "Активирован режим: Только восстановление конфигов"
    START_STEP=7
else
    log_info "Выберите номер шага, с которого нужно начать установку:"
    COLUMNS=1
    while true; do
        select choice in "${STEPS[@]}"; do
            if [[ -z "$choice" ]]; then
                log_warning "Неверный выбор. Введите число от 1 до ${#STEPS[@]}."
                break
            fi
            if [ "$choice" == "Выход" ]; then
                log_info "Выход из скрипта."
                exit 0
            fi
            START_STEP=$REPLY
            log_info "Вы выбрали: $choice. Запускаем с шага $START_STEP."
            break 2
        done
    done
fi

################################################################################
# 1. Обновление системы + RPM Fusion + Flathub
################################################################################
if [ $START_STEP -le 1 ]; then
    hashes
    log_info "Шаг 1: Обновление системы и подключение репозиториев..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: sudo dnf upgrade -y"
        log_info "DRY-RUN: Подключение RPM Fusion (free + nonfree)"
        log_info "DRY-RUN: Добавление Flathub"
        log_success "Симуляция обновления завершена."
    else
        local_output_file=$(mktemp)

        run_update() {
            sudo dnf upgrade -y

            # RPM Fusion
            if ! dnf repolist | grep -q "rpmfusion-free"; then
                log_info "Подключение RPM Fusion (free)..."
                sudo dnf install -y \
                    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
            else
                log_info "RPM Fusion уже подключён."
            fi

            # Flathub
            if ! flatpak remotes | grep -q "flathub"; then
                log_info "Добавление Flathub..."
                flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            else
                log_info "Flathub уже добавлен."
            fi
        }

        if [ "$VERBOSE_MODE" = true ]; then
            if run_update; then
                log_success "Система обновлена, репозитории подключены."
            else
                log_error "КРИТИЧЕСКАЯ ОШИБКА: Не удалось обновить систему."
                exit 1
            fi
        else
            if run_update > "$local_output_file" 2>&1; then
                log_success "Система обновлена, репозитории подключены."
                rm -f "$local_output_file"
            else
                log_error "КРИТИЧЕСКАЯ ОШИБКА: Не удалось обновить систему. Подробности:"
                echo -e "${RED}"
                cat "$local_output_file"
                echo -e "${NC}"
                rm -f "$local_output_file"
                exit 1
            fi
        fi
    fi
fi

if [ "$ONLY_UPDATE" = true ]; then
    log_success "Режим --only-update: завершено."
    [ -n "$LOG_FILE" ] && log_info "Логи сохранены в: $LOG_FILE"
    exit 0
fi

################################################################################
# 2. Установка основных DNF пакетов
################################################################################
if [ $START_STEP -le 2 ] && [ "$SKIP_PACKAGES" = false ]; then
    hashes
    log_info "Шаг 2: Установка основных DNF пакетов..."

    for package in "${DNF_PACKAGES[@]}"; do
        install_dnf_package "$package" || true
    done
    # --- mdcat (COPR: lunaryorn/mdcat) ---
    if [ "$START_STEP" -le 2 ] && [ "$SKIP_PACKAGES" = false ]; then
        if ! command -v mdcat &>/dev/null; then
            log_info "Подключаем COPR репозиторий lunaryorn/mdcat..."
            if [ "$DRY_RUN" = true ]; then
                log_info "DRY-RUN: sudo dnf copr enable lunaryorn/mdcat -y"
                log_info "DRY-RUN: sudo dnf install -y mdcat"
            else
             if sudo dnf copr enable lunaryorn/mdcat -y 2>/dev/null; then
                    install_dnf_package "mdcat" true
                else
                    log_warning "COPR lunaryorn/mdcat недоступен для этой версии Fedora."
                    log_warning "Установи вручную: cargo install mdcat"
                    PACKAGES_FAILED+="mdcat"
                fi
            fi
        else
            loginfo "mdcat уже установлен — пропускаем."
        fi
    fi
    log_success "Основные пакеты установлены"
fi

# --- StarDict dictionaries (sdcv) ---
if [ "${START_STEP}" -le 2 ] && [ "${SKIP_PACKAGES}" = false ]; then
    hashes
    loginfo "Установка словарей StarDict для sdcv..."
    SDCV_DIR="${USER_HOME}/.stardict/dic"
    mkdir -p "${SDCV_DIR}"

    DICT_ENG_RUS="stardict-full-eng-rus-2.4.2.tar.bz2"
    DICT_RUS_ENG="stardict-full-rus-eng-2.4.2.tar.bz2"
    MIRROR="https://stardict.uber.space/ru"

    for DICT in "${DICT_ENG_RUS}" "${DICT_RUS_ENG}"; do
        if [ ! -f "${SDCV_DIR}/${DICT}" ]; then
            loginfo "Скачиваю ${DICT}..."
            if curl -fsSL "${MIRROR}/${DICT}" -o "/tmp/${DICT}"; then
                tar -xjf "/tmp/${DICT}" -C "${SDCV_DIR}"
                rm -f "/tmp/${DICT}"
                logsuccess "Словарь ${DICT} установлен."
            else
                logerror "Не удалось скачать ${DICT}."
                PACKAGES_FAILED+=" sdcv-dict-${DICT}"
            fi
        else
            loginfo "Словарь ${DICT} уже установлен."
        fi
    done
fi

################################################################################
# 3. Установка Docker
################################################################################
if [ $START_STEP -le 3 ] && [ "$SKIP_DOCKER" = false ]; then
    hashes
    log_info "Шаг 3: Установка Docker..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка Docker CE и добавление пользователя в группу docker"
    elif ! command -v docker &>/dev/null; then
        log_info "Docker не установлен, начинаем установку..."

        sudo dnf config-manager addrepo \
            --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

        install_dnf_package "docker-ce" || true
        install_dnf_package "docker-ce-cli" || true
        install_dnf_package "containerd.io" || true
        install_dnf_package "docker-compose-plugin" || true

        sudo systemctl enable --now docker
        log_success "Docker установлен и запущен"
    else
        log_info "Docker уже установлен"
    fi

    if ! id -Gn "$USER" | grep -q docker; then
        log_info "Добавление пользователя в группу docker..."
        drun "sudo usermod -aG docker '$USER'"
        log_info "Пользователь добавлен в группу docker (перезайдите для применения)"
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

    # kubectl
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка kubectl (latest stable)"
    elif ! command -v kubectl &>/dev/null; then
        log_info "Установка kubectl..."
        KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
        drun "curl -LO 'https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl'"
        drun "chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
        log_success "kubectl ${KUBECTL_VERSION} установлен."
    else
        log_info "kubectl уже установлен."
    fi

    # Helm
    if [ "$SKIP_HELM" = false ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: Установка Helm"
        elif ! command -v helm &>/dev/null; then
            log_info "Установка Helm..."
            drun "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
            log_success "Helm установлен."
        else
            log_info "Helm уже установлен."
        fi

        if command -v helm &>/dev/null && [ "$DRY_RUN" = false ]; then
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

################################################################################
# 5. Установка Yandex.Disk
# ВАЖНО: пакет не обновлялся с 2019, в Fedora 44 (RPM 6.0+) требует --nodigest
################################################################################
if [ $START_STEP -le 5 ]; then
    hashes
    log_info "Шаг 5: Установка Yandex.Disk..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка Yandex.Disk RPM с флагом --nodigest"
    elif ! command -v yandex-disk &>/dev/null; then
        log_info "Скачивание Yandex.Disk RPM..."
        YADISK_RPM=$(mktemp --suffix=.rpm)

        if curl -fsSL -o "$YADISK_RPM" "http://repo.yandex.ru/yandex-disk/yandex-disk-latest.x86_64.rpm"; then
            log_info "Установка с флагом --nodigest (обход устаревшей подписи пакета)..."
            # Fedora 44 / RPM 6.0+ не принимает старые digest алгоритмы без этого флага
            if sudo rpm -ivh --nodigest --nofiledigest "$YADISK_RPM"; then
                rm -f "$YADISK_RPM"
                log_success "Yandex.Disk установлен"
                log_warning "Не забудьте настроить Yandex.Disk: yandex-disk setup"
            else
                log_error "Не удалось установить Yandex.Disk"
                rm -f "$YADISK_RPM"
                PACKAGES_FAILED+=("yandex-disk")
            fi
        else
            log_error "Не удалось скачать Yandex.Disk RPM"
            PACKAGES_FAILED+=("yandex-disk")
        fi

        # Отключить репозиторий yandex-disk если он был добавлен (мешает dnf с таймаутами)
        if [ -f /etc/yum.repos.d/yandex-disk.repo ]; then
            sudo dnf config-manager setopt yandex-disk.enabled=0 2>/dev/null || true
            log_info "Репозиторий yandex-disk отключён (избегаем таймаутов dnf)"
        fi
    else
        log_info "Yandex.Disk уже установлен"
    fi
fi

################################################################################
# 6. Установка Flatpak пакетов (Flathub)
################################################################################
if [ $START_STEP -le 6 ] && [ "$SKIP_PACKAGES" = false ]; then
    hashes
    log_info "Шаг 6: Установка Flatpak пакетов..."

    for package in "${FLATPAK_PACKAGES[@]}"; do
        install_flatpak_package "$package" || true
    done

    log_success "Flatpak пакеты установлены"
fi

################################################################################
# 7. Установка AmneziaWG + vpn-awg
################################################################################
if [ $START_STEP -le 7 ]; then
    hashes
    log_info "Шаг 7: Установка AmneziaWG + vpn-awg..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка зависимостей AmneziaWG (kernel-devel, dkms, gcc, make)"
        log_info "DRY-RUN: Сборка amneziawg-linux-kernel-module из GitHub (DKMS)"
        log_info "DRY-RUN: Сборка amneziawg-tools из GitHub"
        log_info "DRY-RUN: Установка vpn-awg в ~/.local/bin/"
    else
        # --- Зависимости сборки ---
        log_info "Установка зависимостей для сборки AmneziaWG..."
        set +e
        sudo dnf install -y \
            "kernel-devel-$(uname -r)" \
            "kernel-headers-$(uname -r)" \
            dkms git curl make gcc iproute \
            2>/dev/null || \
        sudo dnf install -y \
            kernel-devel kernel-headers dkms git curl make gcc iproute \
            2>/dev/null || true
        set -e

        # --- Утилиты awg / awg-quick ---
        if ! command -v awg &>/dev/null || ! command -v awg-quick &>/dev/null; then
            log_info "Сборка amneziawg-tools из исходников..."
            AWG_TOOLS_TMP="$(mktemp -d)"
            set +e
            if git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-tools.git "$AWG_TOOLS_TMP/tools" && \
               cd "$AWG_TOOLS_TMP/tools/src" && sudo make install; then
                log_success "Утилиты awg/awg-quick установлены."
            else
                log_warning "Не удалось собрать amneziawg-tools. VPN-клиент будет недоступен."
                PACKAGES_FAILED+=("amneziawg-tools")
            fi
            cd "$USER_HOME"
            rm -rf "$AWG_TOOLS_TMP"
            set -e
        else
            log_info "Утилиты awg/awg-quick уже установлены."
        fi

        # --- Модуль ядра AmneziaWG (DKMS) ---
        if ! lsmod | grep -q "^amneziawg"; then
            log_info "Сборка модуля ядра amneziawg из GitHub (DKMS)..."
            AWG_MOD_TMP="$(mktemp -d)"
            set +e
            (
                cd "$AWG_MOD_TMP"
                git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git
                cd amneziawg-linux-kernel-module

                DKMS_CONF="$(find . -maxdepth 4 -name dkms.conf | head -n1 || true)"
                VER="1.0.0"
                [ -n "$DKMS_CONF" ] && VER="$(grep -E '^PACKAGE_VERSION=' "$DKMS_CONF" | head -n1 | cut -d= -f2 | tr -d '"' || echo 1.0.0)"

                MAKEFILE="$(find . -maxdepth 4 -name Makefile -print | while read -r mf; do
                    grep -qE '^[[:space:]]*dkms-install:' "$mf" && echo "$mf" && break
                done)"

                if [ -z "$MAKEFILE" ]; then
                    echo "[ERROR] Makefile с целью dkms-install не найден" >&2
                    exit 1
                fi

                cd "$(dirname "$MAKEFILE")"
                if ! sudo make dkms-install 2>/dev/null; then
                    [ ! -d "/usr/src/amneziawg-${VER}" ] && \
                        sudo mkdir -p "/usr/src/amneziawg-${VER}" && \
                        sudo cp -a . "/usr/src/amneziawg-${VER}/"
                fi

                KVER="$(uname -r)"
                sudo dkms add    -m amneziawg -v "${VER}" 2>/dev/null || true
                sudo dkms build  -m amneziawg -v "${VER}" -k "${KVER}"
                sudo dkms install -m amneziawg -v "${VER}" -k "${KVER}"
                sudo depmod -a "${KVER}"
                sudo modprobe amneziawg
            )
            AWG_MOD_RC=$?
            rm -rf "$AWG_MOD_TMP"
            set -e

            if [ $AWG_MOD_RC -eq 0 ]; then
                log_success "Модуль amneziawg собран и загружен."
            else
                log_warning "Сборка модуля amneziawg не удалась."
                if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
                    log_warning "Возможная причина: Secure Boot. Отключи в BIOS или подпиши MOK-ключом."
                fi
                PACKAGES_FAILED+=("amneziawg-kmod")
            fi
        else
            log_info "Модуль amneziawg уже загружен."
        fi

        # --- Системная директория для конфигов ---
        sudo mkdir -p /etc/amnezia/amneziawg

        # --- Установка скрипта vpn-awg ---
        mkdir -p "$USER_HOME/.local/bin"
        VPN_AWG_SRC="$CONFIG_DIR/vpn-awg_fedora.sh"
        if [ -f "$VPN_AWG_SRC" ]; then
            cp "$VPN_AWG_SRC" "$USER_HOME/.local/bin/vpn-awg"
            chmod +x "$USER_HOME/.local/bin/vpn-awg"
            log_success "vpn-awg установлен в ~/.local/bin/vpn-awg"
        else
            log_warning "Файл vpn-awg_fedora.sh не найден в $CONFIG_DIR."
            log_warning "Скопируй его туда и выполни:"
            log_warning "  cp \$CONFIG_DIR/vpn-awg_fedora.sh ~/.local/bin/vpn-awg && chmod +x ~/.local/bin/vpn-awg"
        fi

        # --- Директория для VPN-конфигов hidemy.name ---
        mkdir -p "$USER_HOME/Yandex.Disk/VPN_manager/wg_configs"
        log_info "Директория для VPN-конфигов: ~/Yandex.Disk/VPN_manager/wg_configs/"
        log_info "Скопируй туда *.conf файлы от hidemy.name после настройки Yandex.Disk."
    fi

    log_success "AmneziaWG + vpn-awg настроены"
fi

################################################################################
# 8. Установка шрифтов
################################################################################
if [ $START_STEP -le 8 ]; then
    hashes
    log_info "Шаг 8: Установка шрифтов..."

    mkdir -p "$USER_HOME/.local/share/fonts"

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Копирование шрифтов и обновление кэша"
    elif [ -d "$CONFIG_DIR/fonts" ]; then
        log_info "Копирование шрифтов из конфиг-каталога..."
        drun "cp -r '$CONFIG_DIR/fonts/'*.ttf '$USER_HOME/.local/share/fonts/' 2>/dev/null || true"
        drun "sudo cp '$USER_HOME/.local/share/fonts/'*.ttf /usr/share/fonts/ 2>/dev/null || true"
    else
        log_warning "Шрифты не найдены в '$CONFIG_DIR'. Пропускаем."
    fi

    if [ -d "$USER_HOME/.local/share/fonts" ] && [ "$DRY_RUN" = false ]; then
        fc-cache -f -v "$USER_HOME/.local/share/fonts"
    fi

    log_success "Шрифты установлены"
fi

################################################################################
# 9. Настройка Zsh и Oh My Zsh
################################################################################
if [ $START_STEP -le 9 ]; then
    hashes
    log_info "Шаг 9: Настройка Zsh..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка Oh My Zsh, Powerlevel10k и плагинов"
    else
        if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
            log_info "Установка Oh My Zsh..."
            # Устанавливаем без интерактивного приглашения (--unattended)
            ZSH="$USER_HOME/.oh-my-zsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        else
            log_info "Oh My Zsh уже установлен"
        fi

        if [ ! -d "${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
            log_info "Установка Powerlevel10k..."
            drun "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git '${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/themes/powerlevel10k'"
        else
            log_info "Powerlevel10k уже установлен"
        fi

        # zsh-syntax-highlighting — в HOME (не в плагинах OMZ, совместимость с .zshrc)
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
        [ "$DRY_RUN" = false ] && log_warning ".zshrc не найден в конфиг-каталоге. Используется стандартный шаблон."
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Изменение оболочки на zsh"
    elif ! grep -q "^$USER:.*$(which zsh)$" /etc/passwd 2>/dev/null; then
        log_info "Изменение оболочки по умолчанию на zsh..."
        drun "chsh -s $(which zsh)"
        log_success "Оболочка изменена на zsh"
    else
        log_info "Zsh уже является оболочкой по умолчанию"
    fi

    log_success "Zsh настроен"
fi

################################################################################
# 10. Восстановление .bashrc
################################################################################
if [ $START_STEP -le 10 ]; then
    hashes
    log_info "Шаг 10: Восстановление .bashrc..."

    if [ -f "$CONFIG_DIR/.bashrc" ]; then
        log_info "Восстановление .bashrc из конфиг-каталога..."
        drun "cp '$CONFIG_DIR/.bashrc' '$USER_HOME/.bashrc'"
        log_success ".bashrc восстановлен"
    else
        log_warning ".bashrc не найден в конфиг-каталоге"
    fi
fi

################################################################################
# 11. Настройка NeoVim с AstroNvim
################################################################################
if [ $START_STEP -le 11 ]; then
    hashes
    log_info "Шаг 11: Настройка NeoVim с AstroNvim..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка AstroNvim"
    elif [ ! -d "$USER_HOME/.config/nvim" ]; then
        log_info "Установка AstroNvim..."
        mkdir -p "$BACKUP_DIR"
        drun "[ -d '$USER_HOME/.config/nvim' ]       && mv '$USER_HOME/.config/nvim'       '$BACKUP_DIR/nvim.bak'"
        drun "[ -d '$USER_HOME/.local/share/nvim' ]  && mv '$USER_HOME/.local/share/nvim'  '$BACKUP_DIR/nvim_share.bak'"
        drun "[ -d '$USER_HOME/.local/state/nvim' ]  && mv '$USER_HOME/.local/state/nvim'  '$BACKUP_DIR/nvim_state.bak'"
        drun "[ -d '$USER_HOME/.cache/nvim' ]         && mv '$USER_HOME/.cache/nvim'         '$BACKUP_DIR/nvim_cache.bak'"

        if [ "$DRY_RUN" = false ]; then
            # set +e: не позволяем ошибке git clone убить весь скрипт
            set +e
            if git clone --depth 1 https://github.com/AstroNvim/template "$USER_HOME/.config/nvim"; then
                rm -rf "$USER_HOME/.config/nvim/.git"
                log_success "AstroNvim установлен"
            else
                log_error "Не удалось установить AstroNvim (проверь сеть или наличие ~/.config/nvim)"
            fi
            set -e
        fi
    else
        log_info "AstroNvim уже установлен (~/.config/nvim существует)"
    fi
fi

################################################################################
# 12. Настройка Alacritty и Zellij
################################################################################
if [ $START_STEP -le 12 ]; then
    hashes
    log_info "Шаг 12: Настройка Alacritty и Zellij..."

    if command -v alacritty &>/dev/null; then
        log_info "Alacritty уже установлен"
    else
        log_warning "Alacritty не найден. Убедитесь, что шаг 2 (DNF пакеты) был выполнен."
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Копирование конфига Alacritty и клонирование тем"
    else
        mkdir -p "$USER_HOME/.config/alacritty"

        if [ -f "$CONFIG_DIR/alacritty.toml" ]; then
            log_info "Копирование конфига Alacritty..."
            drun "cp '$CONFIG_DIR/alacritty.toml' '$USER_HOME/.config/alacritty/alacritty.toml'"
            log_success "Конфиг Alacritty скопирован"
        else
            log_warning "alacritty.toml не найден в $CONFIG_DIR"
        fi

        if [ ! -d "$USER_HOME/.config/alacritty/themes" ]; then
            log_info "Клонирование коллекции тем Alacritty..."
            set +e
            if git clone https://github.com/alacritty/alacritty-theme "$USER_HOME/.config/alacritty/themes"; then
                log_success "Темы Alacritty установлены"
            else
                log_warning "Не удалось клонировать темы Alacritty."
            fi
            set -e
        else
            log_info "Темы Alacritty уже установлены"
        fi
    fi

    if [ -f "$CONFIG_DIR/alacritty-theme" ]; then
        log_info "Копирование скрипта alacritty-theme..."
        mkdir -p "$USER_HOME/.local/bin"
        drun "cp '$CONFIG_DIR/alacritty-theme' '$USER_HOME/.local/bin/alacritty-theme'"
        drun "chmod +x '$USER_HOME/.local/bin/alacritty-theme'"
        log_success "Скрипт alacritty-theme установлен в ~/.local/bin/"
    else
        log_warning "Скрипт alacritty-theme не найден в $CONFIG_DIR"
    fi

    # Zellij: сначала проверяем бинарник в system_configs, потом качаем с GitHub
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Установка Zellij"
    elif command -v zellij &>/dev/null; then
        log_info "Zellij уже установлен: $(zellij --version)"
    elif [ -f "$CONFIG_DIR/zellij" ]; then
        log_info "Копирование бинарника Zellij из конфиг-каталога..."
        mkdir -p "$USER_HOME/.local/bin"
        drun "cp '$CONFIG_DIR/zellij' '$USER_HOME/.local/bin/zellij'"
        drun "chmod +x '$USER_HOME/.local/bin/zellij'"
        log_success "Zellij установлен в ~/.local/bin/zellij"
    else
        log_info "Бинарник zellij не найден в $CONFIG_DIR, скачиваем с GitHub..."
        ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | grep tag_name | cut -d '"' -f 4)
        if [ -n "$ZELLIJ_VERSION" ]; then
            ZELLIJ_URL="https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz"
            log_info "Скачивание Zellij $ZELLIJ_VERSION..."
            mkdir -p "$USER_HOME/.local/bin"
            set +e
            if curl -fsSL "$ZELLIJ_URL" | tar xz -C "$USER_HOME/.local/bin/"; then
                chmod +x "$USER_HOME/.local/bin/zellij"
                log_success "Zellij $ZELLIJ_VERSION установлен в ~/.local/bin/"
            else
                log_error "Не удалось скачать Zellij"
                PACKAGES_FAILED+=("zellij")
            fi
            set -e
        else
            log_error "Не удалось определить последнюю версию Zellij"
            PACKAGES_FAILED+=("zellij")
        fi
    fi

    # Добавить ~/.local/bin в PATH в .zshrc (нужно для Zellij и других утилит)
    if [ -f "$USER_HOME/.zshrc" ]; then
        append_to_file_once "$USER_HOME/.zshrc" \
            'export PATH="$HOME/.local/bin:$PATH"' \
            "Добавление ~/.local/bin в PATH"
    fi

    log_success "Alacritty и Zellij настроены"
fi

################################################################################
# 13. Настройка GNOME
################################################################################
if [ $START_STEP -le 13 ]; then
    hashes
    log_info "Шаг 13: Настройка GNOME..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Настройка GNOME расширений и параметров"
    else
        # Включить системный трей (AppIndicator) — в Fedora по умолчанию выключен
        if command -v gnome-extensions &>/dev/null; then
            drun "gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com 2>/dev/null || true"
            log_info "AppIndicator (системный трей) активирован"
        fi

        # Отключить донат-напоминание и автообновления GNOME Software
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.software allow-updates false 2>/dev/null || true
            gsettings set org.gnome.software download-updates false 2>/dev/null || true
            gsettings set org.gnome.settings-daemon.plugins.housekeeping donation-reminder-enabled false 2>/dev/null || true
            log_info "Автообновления GNOME Software отключены"
        fi
    fi
    # === GNOME EXTENSIONS ===
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: sudo dnf install -y gnome-shell-extension-no-overview"
    else
        sudo dnf install -y gnome-shell-extension-no-overview || true
        gnome-extensions enable no-overview@fthx 2>/dev/null || true
    fi
    log_warning " Включить после первого логина: - gnome-extensions enable no-overview@fthx"
    log_warning "Для установки GNOME расширений через браузер (установи GNOME Shell Integration):"
    log_warning " - Media Controls:      https://extensions.gnome.org/extension/4470/media-controls/"
    log_warning " - Privacy Menu:        https://extensions.gnome.org/extension/4491/privacy-menu/"
    log_warning " - Top Bar Organizer:   https://extensions.gnome.org/extension/4356/top-bar-organizer/"
    log_warning " - Quick Lang Switch:   https://extensions.gnome.org/extension/4559/quick-lang-switch/"
fi

################################################################################
# 14. Установка Yandex Browser
################################################################################
# if [ $START_STEP -le 14 ] && [ "$SKIP_PACKAGES" = false ]; then
#     hashes
#     log_info "Шаг 14: Установка Yandex Browser..."
#
#     if [ "$DRY_RUN" = true ]; then
#         log_info "DRY-RUN: Установка Yandex Browser (RPM репозиторий)"
#     elif ! command -v yandex-browser-stable &>/dev/null; then
#         log_info "Добавление репозитория Yandex Browser..."
#         sudo rpmkeys --import https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG 2>/dev/null || true
#
#         sudo tee /etc/yum.repos.d/yandex-browser-stable.repo > /dev/null << 'REPO'
# [yandex-browser-stable]
# name=Yandex Browser (stable)
# baseurl=https://repo.yandex.ru/yandex-browser/rpm/stable/x86_64
# enabled=1
# gpgcheck=1
# gpgkey=https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG
# REPO
#
#         set +e
#         if sudo dnf install -y yandex-browser-stable; then
#             log_success "Yandex Browser установлен"
#         else
#             log_warning "Не удалось установить Yandex Browser через DNF"
#             PACKAGES_FAILED+=("yandex-browser-stable")
#         fi
#         set -e
#     else
#         log_info "Yandex Browser уже установлен"
#     fi
# fi

################################################################################
# 15. Восстановление SSH ключей
################################################################################
if [ $START_STEP -le 15 ]; then
    hashes
    log_info "Шаг 15: Восстановление SSH ключей..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Восстановление SSH ключей из бэкапа"
    elif [ -f "$CONFIG_DIR/ssh_keys_backup.zip" ]; then
        mkdir -p "$USER_HOME/.ssh"

        if [ "$(ls -A "$USER_HOME/.ssh" 2>/dev/null)" ]; then
            log_warning "В директории .ssh уже есть файлы. Создаём бэкап в $BACKUP_DIR/ssh_backup"
            drun "cp -r '$USER_HOME/.ssh' '$BACKUP_DIR/ssh_backup'"
        fi

        drun "unzip -o '$CONFIG_DIR/ssh_keys_backup.zip' -d '$USER_HOME/.ssh/'"
        drun "chmod 700 '$USER_HOME/.ssh'"
        # Устанавливаем права на все файлы, кроме .pub
        drun "find '$USER_HOME/.ssh' -type f ! -name '*.pub' -exec chmod 600 {} \;"
        drun "find '$USER_HOME/.ssh' -type f -name '*.pub' -exec chmod 644 {} \;"
        log_success "SSH ключи восстановлены"
    else
        log_warning "Бэкап SSH ключей не найден в $CONFIG_DIR/ssh_keys_backup.zip"
    fi
fi

################################################################################
# 16. Настройка Git
################################################################################
if [ $START_STEP -le 16 ]; then
    hashes
    log_info "Шаг 16: Настройка Git..."

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Настройка Git конфигурации"
    elif ! git config --global user.email &>/dev/null; then
        drun "git config --global user.email 'toxusa@yandex.ru'"
        drun "git config --global user.name 'toxusa'"
        drun "git config --global credential.helper 'cache --timeout=3600'"
        drun "git config --global core.editor 'vim'"
        log_success "Git настроен"
    else
        log_info "Git уже настроен (email: $(git config --global user.email))"
    fi
fi

################################################################################
# 17. Настройка алиасов и p10k
################################################################################
if [ $START_STEP -le 17 ]; then
    hashes
    log_info "Шаг 17: Настройка алиасов и Powerlevel10k..."

    if [ -f "$CONFIG_DIR/.p10k.zsh" ]; then
        log_info "Восстановление .p10k.zsh..."
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: cp '$CONFIG_DIR/.p10k.zsh' '$USER_HOME/.p10k.zsh'"
        else
            drun "cp '$CONFIG_DIR/.p10k.zsh' '$USER_HOME/.p10k.zsh'"
            log_success ".p10k.zsh восстановлен"
        fi
    else
        log_info ".p10k.zsh не найден. После перезагрузки выполните: p10k configure"
    fi

    # NVM (закомментировано по умолчанию — раскомментируй при необходимости)
    # if [ ! -d "$USER_HOME/.nvm" ]; then
    #     log_info "Установка NVM..."
    #     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
    #     log_success "NVM установлен"
    # else
    #     log_info "NVM уже установлен"
    # fi
fi

################################################################################
# 18. Настройка аппаратных компонентов ThinkPad X1 Carbon Gen 9
################################################################################
if [ $START_STEP -le 18 ]; then
    hashes
    log_info "Шаг 18: Настройка аппаратных компонентов ThinkPad X1 Carbon Gen 9..."

    # --- FCC-разблокировка WWAN модема (Quectel EM120R-GL) ---
    if mmcli --list-modems 2>/dev/null | grep -qi "quectel\|em120"; then
        log_info "Обнаружен WWAN модем Quectel EM120R-GL, выполняем FCC-разблокировку..."

        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: Создание симлинка FCC-unlock для модема (1eac:1001)"
        else
            UNLOCK_DIR="/etc/ModemManager/fcc-unlock.d"
            UNLOCK_SRC="/usr/share/ModemManager/fcc-unlock.available.d/1eac:1001"

            if [ -f "$UNLOCK_SRC" ]; then
                sudo mkdir -p "$UNLOCK_DIR"
                sudo ln -sfn "$UNLOCK_SRC" "$UNLOCK_DIR/1eac:1001"
                sudo systemctl daemon-reload
                sudo systemctl restart ModemManager
                sleep 3
                log_success "FCC-разблокировка WWAN настроена. Перезагрузка рекомендуется."
            else
                log_warning "Файл $UNLOCK_SRC не найден."
                log_warning "Выполни вручную: sudo ln -sfn /usr/share/ModemManager/fcc-unlock.available.d/1eac:1001 /etc/ModemManager/fcc-unlock.d/1eac:1001"
            fi
        fi
    else
        log_info "WWAN модем не обнаружен (или mmcli недоступен). Пропускаем FCC-разблокировку."
        log_info "Для ручной настройки LTE: см. документацию в Obsidian (fedora-x1-gen9-guide.md)"
    fi

    # --- Сканер отпечатков пальцев ---
    if lsusb 2>/dev/null | grep -qi "06cb:00fc\|prometheus"; then
        log_info "Обнаружен сканер Synaptics Prometheus (06cb:00fc)"

        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: Обновление прошивки и включение fingerprint в PAM"
        else
            # Обновить прошивку через LVFS (ключевой шаг для стабильной работы)
            if command -v fwupdmgr &>/dev/null; then
                log_info "Обновление прошивок через LVFS..."
                set +e
                fwupdmgr refresh --force 2>/dev/null || true
                fwupdmgr update -y 2>/dev/null || true
                set -e
                log_success "Прошивки обновлены (или уже актуальны)"
            else
                log_warning "fwupdmgr не найден. Установи: sudo dnf install fwupd"
            fi

            # Включить fingerprint-аутентификацию через authselect
            if command -v authselect &>/dev/null; then
                log_info "Включение fingerprint-аутентификации через authselect..."
                set +e
                sudo authselect enable-feature with-fingerprint 2>/dev/null || true
                sudo authselect apply-changes 2>/dev/null || true
                set -e
                log_success "Fingerprint-аутентификация включена (PAM)"
            fi
        fi
    else
        log_info "Сканер отпечатков пальцев не обнаружен через lsusb."
        log_info "Для ручной настройки: fprintd-enroll && sudo authselect enable-feature with-fingerprint"
    fi

    # --- TLP для оптимизации энергопотребления ---
    if ! command -v tlp &>/dev/null; then
        log_info "Установка TLP (управление питанием для ноутбука)..."
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: sudo dnf install -y tlp tlp-rdw"
        else
            set +e
            if sudo dnf install --allowerasing tlp tlp-pd tlp-rdw -y 2>/dev/null; then
                sudo systemctl enable --now tlp.service
                sudo systemctl enable --now tlp-pd.service
                sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
                # Пороги заряда батареи (75/80 — оптимально для ThinkPad на зарядке)
                if grep -q "START_CHARGE_THRESH_BAT0" /etc/tlp.conf; then
                    sudo sed -i 's/^#\?START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=75/' /etc/tlp.conf
                    sudo sed -i 's/^#\?STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=80/' /etc/tlp.conf
                else
                    echo "START_CHARGE_THRESH_BAT0=75" | sudo tee -a /etc/tlp.conf
                    echo "STOP_CHARGE_THRESH_BAT0=80" | sudo tee -a /etc/tlp.conf
                fi
                sudo tlp start
                # === SUSPEND MODE ===
                # Deep sleep (S3) вместо s2idle — стабильнее на ThinkPad X1 Carbon Gen 9
                sudo grubby --update-kernel=ALL --args="mem_sleep_default=deep"
                # === WWAN AUTO-RECOVERY ===
                cat <<'UNIT' | sudo tee /etc/systemd/system/wwan-reset.service
                [Unit]
                Description=Reset WWAN modem after suspend
                After=suspend.target hibernate.target hybrid-sleep.target
                [Service]
                Type=oneshot
                ExecStart=/bin/bash -c 'rfkill block wwan; sleep 3; rfkill unblock wwan; sleep 5; systemctl restart ModemManager'
                [Install]
                WantedBy=suspend.target hibernate.target hybrid-sleep.target
                UNIT
                sudo systemctl enable --now wwan-reset.service
                log_success "TLP установлен и запущен (энергопотребление оптимизировано)"
            else
                log_warning "Не удалось установить TLP"
            fi
            set -e
        fi
    else
        log_info "TLP уже установлен"
    fi

    log_success "Аппаратные компоненты ThinkPad X1 Carbon Gen 9 настроены"
    # --- EasyEffects для всех 4 динамиков ---
    if ! flatpak list 2>/dev/null | grep -q "com.github.wwmm.easyeffects"; then
        log_info "Установка EasyEffects (активация всех 4 динамиков X1 Carbon)..."
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY-RUN: flatpak install -y flathub com.github.wwmm.easyeffects"
        else
            set +e
            if flatpak install -y flathub com.github.wwmm.easyeffects 2>/dev/null; then
                # Пресеты JackHack96 для ThinkPad X1
                PRESETS_DIR="$USER_HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output"
                mkdir -p "$PRESETS_DIR"
                if git clone --depth=1 https://github.com/JackHack96/EasyEffects-Presets /tmp/easyeffects-presets 2>/dev/null; then
                    cp /tmp/easyeffects-presets/*.json "$PRESETS_DIR/" 2>/dev/null || true
                    rm -rf /tmp/easyeffects-presets
                    log_success "EasyEffects установлен, пресеты JackHack96 добавлены"
                    log_warning "Откройте EasyEffects → Output → выберите пресет 'Laptop' → включите 'Launch at Login'"
                else
                    log_warning "EasyEffects установлен, но пресеты не удалось скачать (проверь сеть)"
                    log_warning "Вручную: https://github.com/JackHack96/EasyEffects-Presets"
                fi
            else
                log_warning "Не удалось установить EasyEffects"
            fi
            set -e
        fi
    else
        log_info "EasyEffects уже установлен"
    fi
fi

################################################################################
# 19. Финальные действия
################################################################################
if [ $START_STEP -le 19 ]; then
    log_success "============================================"
    log_success "Установка Fedora 44 завершена!"
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
    echo "2. Запустите настройку Powerlevel10k: p10k configure"
    echo "3. Зарегистрируйте отпечаток пальца: fprintd-enroll -f right-index-finger"
    echo "4. Включите LTE: sudo mmcli -m 0 --enable && nmcli radio wwan on"
    echo "5. Установите GNOME расширения через Extension Manager (Flatpak)"
    echo "6. Проверьте SSH ключи: ls -la ~/.ssh/"
    echo "7. Настройте Yandex.Disk: yandex-disk setup"
    echo "8. Проверьте Docker: docker run hello-world"
    echo "9. Проверить автовосстановление WWAN после suspend: systemctl status wwan-reset.service"
    echo "10. Проверить режим сна: cat /sys/power/mem_sleep  # ожидается [deep]"
    echo ""

    if [ "$DRY_RUN" = false ]; then
        log_info "Проверка ключевых компонентов системы..."
        check_docker_installation || true

        if command -v yandex-disk &>/dev/null; then
            if [ -f "$USER_HOME/.config/yandex-disk/config.cfg" ]; then
                log_info "Yandex.Disk уже настроен."
            else
                read -p "Выполнить первоначальную настройку Yandex.Disk сейчас? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    yandex-disk setup
                    log_success "Настройка Yandex.Disk завершена."
                else
                    log_info "Запустите позже: yandex-disk setup"
                fi
            fi
        fi
    fi

    log_info "Бэкапы старых конфигов сохранены в: $BACKUP_DIR"
    echo ""
    log_warning "Рекомендуется перезагрузить систему: sudo reboot"

    [ -n "$LOG_FILE" ] && log_info "Логи сохранены в: $LOG_FILE"
fi
