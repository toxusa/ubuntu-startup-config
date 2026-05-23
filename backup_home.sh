#!/bin/bash

# Каталог назначения в Яндекс.Диске (папка с текущей датой)
BACKUP_DIR="$HOME/Yandex.Disk/Ubuntu_Backup_$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

echo "=== 1. Экспорт настроек GNOME ==="
# Сохраняем все настройки GNOME, шорткаты и конфигурации расширений
dconf dump / > "$BACKUP_DIR/gnome_settings_backup.ini"
echo "Настройки GNOME сохранены."

echo "=== 2. Создание защищенного архива ключей и конфигов ==="
# Собираем список критичных папок и файлов, если они существуют
TARGETS=""
for item in .ssh .gnupg .kube .config .local/bin .zshrc .bashrc .p10k.zsh system_configs alacritty.toml; do
    if [ -e "$HOME/$item" ]; then
        TARGETS="$TARGETS $item"
    fi
done

# Архивируем с сохранением прав доступа (флаг -p)
tar -czpf "$BACKUP_DIR/keys_and_dotfiles.tar.gz" -C "$HOME" $TARGETS
echo "Архив с ключами и конфигами создан: keys_and_dotfiles.tar.gz"

echo "=== 3. Синхронизация остальных файлов (rsync) ==="
# Копируем проекты, документы и прочее. Исключаем кэш и тяжелые временные папки.
rsync -aP \
    --exclude="Yandex.Disk/" \
    --exclude=".cache/" \
    --exclude=".local/share/Trash/" \
    --exclude="Downloads/" \
    --exclude="node_modules/" \
    --exclude=".npm/" \
    --exclude=".var/app/" \
    --exclude=".mozilla/" \
    --exclude=".config/google-chrome/" \
    "$HOME/" "$BACKUP_DIR/home_files/"

echo "=== ГОТОВО! ==="
echo "Резервная копия успешно создана в: $BACKUP_DIR"
