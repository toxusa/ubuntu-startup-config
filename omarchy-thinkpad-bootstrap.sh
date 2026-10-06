#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:toxusa/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.backup-omarchy/$(date +%F-%H%M%S)}"

PACKAGES=(
  git stow
  bash ble.sh
  foot starship
  tmux
  ripgrep fd bat eza fastfetch
  btop htop
  jq curl unzip zip
  neovim
  wl-clipboard cliphist
  networkmanager modemmanager
  bluez bluez-utils
  ttf-jetbrains-mono-nerd
)

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Запускай скрипт от обычного пользователя, без sudo."
command -v pacman >/dev/null || die "Это не Arch/Omarchy: pacman не найден."

say "1/8. Обновление системы и базовые пакеты"
sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

say "2/8. UTF-8 locale: en_GB — понедельник первым днём недели"
sudo cp -a /etc/locale.gen "/etc/locale.gen.backup.$(date +%F-%H%M%S)"
sudo cp -a /etc/locale.conf "/etc/locale.conf.backup.$(date +%F-%H%M%S)" 2>/dev/null || true

for loc in en_GB en_US; do
  if grep -qE "^#[[:space:]]*${loc}\.UTF-8[[:space:]]+UTF-8" /etc/locale.gen; then
    sudo sed -i -E \
      "s|^#[[:space:]]*(${loc}\.UTF-8[[:space:]]+UTF-8)[[:space:]]*$|\1|" \
      /etc/locale.gen
  elif ! grep -qE "^${loc}\.UTF-8[[:space:]]+UTF-8" /etc/locale.gen; then
    printf '%s.UTF-8 UTF-8\n' "$loc" | sudo tee -a /etc/locale.gen >/dev/null
  fi
done

sudo locale-gen
sudo tee /etc/locale.conf >/dev/null <<'EOF'
LANG=en_GB.UTF-8
EOF

locale -a | grep -qi '^en_gb\.utf8$' || die "en_GB.UTF-8 не сгенерировалась."
LC_TIME=en_GB.UTF-8 locale first_weekday | grep -qx '2' ||
  warn "Не удалось автоматически подтвердить понедельник как первый день недели."

say "3/8. Dotfiles"
if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  git -C "$DOTFILES_DIR" pull --ff-only
fi

mkdir -p "$BACKUP_DIR"

# Конфликтующие пути именно используемых Omarchy stow-пакетов.
for p in \
  "$HOME/.bashrc" \
  "$HOME/.config/bash" \
  "$HOME/.config/blesh" \
  "$HOME/.config/foot" \
  "$HOME/.config/tmux" \
  "$HOME/.config/starship.toml"
do
  if [[ -e "$p" && ! -L "$p" ]]; then
    target="$BACKUP_DIR/${p#$HOME/}"
    mkdir -p "$(dirname "$target")"
    mv -- "$p" "$target"
    printf 'Moved: %s -> %s\n' "$p" "$target"
  fi
done

cd "$DOTFILES_DIR"
stow -nv --target="$HOME" \
  bash_omarchy foot_omarchy tmux starship ||
  die "Stow simulation обнаружила конфликт. Ничего не было применено."

stow -v --target="$HOME" \
  bash_omarchy foot_omarchy tmux starship

say "4/8. Hyprland: раскладки и тачпад"
mkdir -p "$HOME/.config/hypr"

cat >"$HOME/.config/hypr/input.lua" <<'EOF'
hl.config {
  input = {
    kb_layout = "us,ru",
    kb_options = "grp:win_space_toggle,caps:menu,shift:both_capslock_cancel",
    touchpad = {
      natural_scroll = true,
    },
  },
}
EOF

cat >"$HOME/.config/hypr/bindings.lua" <<'EOF'
hl.unbind("SUPER", "SPACE")
hl.unbind("", "Menu")
o.bind("Menu", "Omarchy menu", "omarchy-menu toggle")
EOF

say "5/8. Bluetooth: не включать автоматически"
if [[ -f /etc/bluetooth/main.conf ]]; then
  sudo cp -a /etc/bluetooth/main.conf \
    "/etc/bluetooth/main.conf.backup.$(date +%F-%H%M%S)"
  sudo sed -i -E \
    's/^[[:space:]]*#?[[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable=false/' \
    /etc/bluetooth/main.conf
fi
sudo systemctl enable bluetooth.service

say "6/8. LTE/WWAN: сервисы, без автоподключения"
sudo systemctl enable NetworkManager.service ModemManager.service

say "7/8. Проверки"
printf '\n--- locale ---\n'
locale
printf '\n--- generated English locales ---\n'
locale -a | grep -iE '^(en_gb|en_us)\.utf' || true
printf '\n--- stow links ---\n'
for p in \
  "$HOME/.bashrc" \
  "$HOME/.config/bash" \
  "$HOME/.config/blesh" \
  "$HOME/.config/foot" \
  "$HOME/.config/tmux" \
  "$HOME/.config/starship.toml"
do
  printf '%s -> %s\n' "$p" "$(readlink -f "$p" 2>/dev/null || echo 'NOT A LINK')"
done

printf '\n--- Hyprland config errors ---\n'
hyprctl configerrors 2>/dev/null || true

say "8/8. Готово"
cat <<EOF

Бэкап конфликтующих Omarchy-файлов:
  $BACKUP_DIR

Нужен выход из Hyprland и повторный вход (или перезагрузка):
  systemctl reboot

После входа проверь:
  locale
  LC_TIME=en_GB.UTF-8 locale first_weekday
  hyprctl configerrors
  ble-face | grep -E 'auto_complete|syntax_error'
  git -C ~/.dotfiles status -sb

LTE и Bluetooth намеренно не включаются автоматически.
EOF
