#!/usr/bin/env bash
# Idempotent backup + restore + bootstrap for toxusa's Omarchy workstations.
# Run as a regular user. The script invokes sudo only where needed.
set -Eeuo pipefail
shopt -s nullglob

VERSION="2026.10.06.2"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-setup"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/toxusa/dotfiles.git}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/Yandex.Disk/system_configs}"
LOCALE_LANG="${LOCALE_LANG:-en_US.UTF-8}"
LOCALE_TIME="${LOCALE_TIME:-en_GB.UTF-8}"
NFS_SOURCE="${NFS_SOURCE:-192.168.1.10:/data/nas/files}"
NFS_TARGET="${NFS_TARGET:-/media/files}"
PLUGIN_CAL_URL="${PLUGIN_CAL_URL:-https://github.com/tmn73/omarchy-calendar.git}"
PLUGIN_CAL_ID="tmn73.calendar"
PLUGIN_ALTTAB_URL="${PLUGIN_ALTTAB_URL:-https://github.com/c4software/hyprland-alttab.git}"
PLUGIN_ALTTAB_ID="vbrosseau.alttab"
GCLOUD_URL="${GCLOUD_URL:-https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz}"
GCLOUD_DIR="${GCLOUD_DIR:-$HOME/.local/share/google-cloud-sdk}"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
WITH_THINKPAD=false
WITH_TLP=false
WITH_DOCKER=true
WITH_CALENDAR_AUTH=false
WITH_PLYMOUTH=true
WITH_MOUNT=true
DRY_RUN=false
FORCE=false
BACKUP_FROM=""

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32mOK: %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mXX %s\033[0m\n' "$*" >&2; exit 1; }

on_error() {
  local rc=$? line=${BASH_LINENO[0]:-?}
  printf '\033[1;31mXX Ошибка %s на строке %s\033[0m\n' "$rc" "$line" >&2
  exit "$rc"
}
trap on_error ERR

usage() {
  cat <<'EOF'
Omarchy backup/restore/bootstrap

Usage:
  omarchy-setup.sh backup [--backup-root DIR]
  omarchy-setup.sh setup [options]
  omarchy-setup.sh restore --from BACKUP_DIR [--force]
  omarchy-setup.sh all --from BACKUP_DIR [options]
  omarchy-setup.sh calendar-auth
  omarchy-setup.sh verify

Options:
  --from DIR          Каталог одного бэкапа (с private-home.tar.gz.gpg)
  --backup-root DIR   Родительский каталог новых бэкапов
  --thinkpad          Настроить X1 Carbon Gen 9: WWAN, Bluetooth, fingerprint pkg
  --with-tlp          Дополнительно включить TLP с порогами 75/80
  --skip-docker       Не устанавливать и не настраивать Docker
  --skip-plymouth     Не убирать логотип Omarchy из Plymouth
  --skip-mount        Записать NFS в fstab, но не пытаться монтировать
  --calendar-auth     В конце запустить интерактивный OAuth-мастер календаря
  --force             Повторно применить уже восстановленный бэкап
  --dry-run           Показывать изменяющие команды без выполнения
  -h, --help          Справка

Examples:
  ./omarchy-setup.sh backup
  ./omarchy-setup.sh setup --thinkpad --dry-run
  ./omarchy-setup.sh all --from ~/migration-X1-20261006-120000 --thinkpad
  ./omarchy-setup.sh verify

Environment overrides:
  DOTFILES_REPO, DOTFILES_DIR, BACKUP_ROOT, LOCALE_LANG, LOCALE_TIME,
  NFS_SOURCE, NFS_TARGET, GCLOUD_URL, GCLOUD_SHA256
EOF
}

run() {
  printf '+ '; printf '%q ' "$@"; printf '\n'
  "$DRY_RUN" || "$@"
}

run_root() { run sudo "$@"; }

need_regular_user() {
  [[ $EUID -ne 0 ]] || die "Не запускай скрипт через sudo; sudo будет вызван точечно."
}

need_omarchy() {
  command -v omarchy >/dev/null 2>&1 || die "Команда omarchy не найдена. Сначала установи Omarchy."
  command -v pacman >/dev/null 2>&1 || die "Этот этап рассчитан на Omarchy/Arch с pacman."
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

backup_file_once() {
  local path=$1 copy="${1}.omarchy-setup-original"
  [[ -e "$path" ]] || return 0
  [[ -e "$copy" ]] || run_root cp -a -- "$path" "$copy"
}

write_if_changed() {
  local target=$1 mode=$2 tmp
  tmp=$(mktemp)
  cat >"$tmp"
  if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    return 0
  fi
  run install -D -m "$mode" "$tmp" "$target"
  rm -f "$tmp"
}

###############################################################################
# BACKUP (works on Fedora, Ubuntu, Arch/Omarchy)
###############################################################################

copy_into_stage() {
  local src=$1 stage=$2 rel dest
  [[ -e "$src" || -L "$src" ]] || return 0
  case "$src" in
    "$HOME"/*) rel=${src#"$HOME"/}; dest="$stage/home/$rel" ;;
    /etc/*)    rel=${src#/}; dest="$stage/system/$rel" ;;
    *) warn "Пропущен путь вне HOME и /etc: $src"; return 0 ;;
  esac
  mkdir -p "$(dirname "$dest")"
  cp -a -- "$src" "$dest"
  printf '%s\n' "$src" >>"$stage/MANIFEST.paths"
}

collect_inventory() {
  local out=$1
  mkdir -p "$out"
  {
    echo "created=$(date --iso-8601=seconds)"
    echo "host=$(hostname)"
    echo "user=$USER"
    echo "kernel=$(uname -srmo)"
    [[ -r /etc/os-release ]] && cat /etc/os-release
  } >"$out/system.txt"

  if command_exists rpm; then rpm -qa | sort >"$out/packages-rpm.txt"; fi
  if command_exists dnf; then dnf repoquery --userinstalled --qf '%{name}' 2>/dev/null | sort -u >"$out/packages-dnf-user.txt" || true; fi
  if command_exists dpkg-query; then dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort >"$out/packages-deb.txt"; fi
  if command_exists apt-mark; then apt-mark showmanual | sort >"$out/packages-apt-manual.txt"; fi
  if command_exists pacman; then pacman -Qqe | sort >"$out/packages-pacman-explicit.txt"; pacman -Qqm | sort >"$out/packages-aur.txt" || true; fi
  if command_exists flatpak; then flatpak list --app --columns=application,origin | sort >"$out/flatpak-apps.txt"; fi
  if command_exists nmcli; then
    nmcli -f NAME,UUID,TYPE,AUTOCONNECT connection show >"$out/network-connections.txt" 2>/dev/null || true
  fi
  if command_exists systemctl; then
    systemctl --user list-unit-files --state=enabled --no-pager >"$out/user-units-enabled.txt" 2>/dev/null || true
    systemctl list-unit-files --state=enabled --no-pager >"$out/system-units-enabled.txt" 2>/dev/null || true
  fi
  git -C "$DOTFILES_DIR" remote -v >"$out/dotfiles-remote.txt" 2>/dev/null || true
  git -C "$DOTFILES_DIR" status --short >"$out/dotfiles-status.txt" 2>/dev/null || true
  git -C "$DOTFILES_DIR" log -1 --oneline >"$out/dotfiles-head.txt" 2>/dev/null || true
}

backup_home() {
  need_regular_user
  command_exists gpg || die "Нужен gpg/gnupg."
  command_exists tar || die "Нужен tar."

  local stamp host dest tmp archive
  stamp=$(date +%Y%m%d-%H%M%S)
  host=$(hostname -s 2>/dev/null || hostname)
  dest="$BACKUP_ROOT/migration-${host}-${stamp}"
  tmp=$(mktemp -d)
  archive="$dest/private-home.tar.gz.gpg"
  trap 'rm -rf "${tmp:-}"' RETURN
  umask 077
  mkdir -p "$dest" "$tmp/stage"

  log "Собираю приватные данные"
  local paths=(
    "$HOME/.ssh"
    "$HOME/.gnupg"
    "$HOME/.config/git"
    "$HOME/.gitconfig"
    "$HOME/.local/state/syncthing"
    "$HOME/.config/syncthing"
    "$HOME/.config/yandex-disk"
    "$HOME/.zen"
    "$HOME/.config/zen"
    "$HOME/.kube"
    "$HOME/.minikube"
    "$HOME/.config/helm"
    "$HOME/.config/k9s"
    "$HOME/.config/xray"
    "$HOME/.config/hysteria"
    "$HOME/.config/gws-omarchy-calendar"
    "$HOME/.config/omarchy/calendar-sync.json"
    "$HOME/.config/systemd/user/omarchy-calendar-sync.service"
    "$HOME/.config/systemd/user/omarchy-calendar-sync.timer"
    "$HOME/.local/state/omarchy/calendar-events.json"
    "$HOME/.stardict"
    "$HOME/.local/share/stardict"
    "$HOME/.local/share/fonts"
    "$HOME/.config/mpv"
    "$HOME/.config/glow"
    "$HOME/.config/yt-dlp"
    "$HOME/.local/bin/xray"
    "$HOME/.local/bin/hysteria"
    "$HOME/.local/bin/tun2socks"
    "$HOME/.local/bin/pynvim-python"
    "$HOME/Obsidian"
    "$HOME/Documents"
    "/etc/hosts"
    "/etc/fstab"
    "/etc/locale.conf"
  )
  local p
  for p in "${paths[@]}"; do copy_into_stage "$p" "$tmp/stage"; done

  if command_exists sudo; then
    sudo tar -czf "$tmp/system-root-readable.tar.gz" \
      --ignore-failed-read \
      /root/.ssh /etc/NetworkManager/system-connections /etc/ModemManager \
      /etc/bluetooth/main.conf /etc/tlp.d /etc/systemd/system 2>/dev/null || true
    [[ -s "$tmp/system-root-readable.tar.gz" ]] && \
      mv "$tmp/system-root-readable.tar.gz" "$tmp/stage/system-root-readable.tar.gz"
  fi

  collect_inventory "$tmp/stage/inventory"
  sort -u -o "$tmp/stage/MANIFEST.paths" "$tmp/stage/MANIFEST.paths" 2>/dev/null || true
  printf '%s\n' "$VERSION" >"$tmp/stage/BACKUP_VERSION"
  printf '%s\n' "$HOME" >"$tmp/stage/BACKUP_HOME"

  log "Создаю зашифрованный архив; GPG запросит пароль"
  local archive_tmp="$tmp/private-home.tar.gz.gpg"
  tar -C "$tmp/stage" -czf - . | gpg --symmetric --cipher-algo AES256 --compress-algo none --output "$archive_tmp"
  chmod 600 "$archive_tmp"
  mv "$archive_tmp" "$archive"
  chmod 600 "$archive"
  (cd "$dest" && sha256sum "$(basename "$archive")" >SHA256SUMS)
  cp "$tmp/stage/MANIFEST.paths" "$dest/MANIFEST.paths"
  cp "$tmp/stage/inventory/system.txt" "$dest/SYSTEM.txt"
  chmod 600 "$dest/MANIFEST.paths" "$dest/SYSTEM.txt" "$dest/SHA256SUMS"

  gpg --list-packets "$archive" >/dev/null 2>&1 || die "GPG-архив не прошёл структурную проверку."
  ok "Бэкап создан: $dest"
  echo "Проверка позже: cd '$dest' && sha256sum -c SHA256SUMS"
}

###############################################################################
# PACKAGE INSTALLATION
###############################################################################

pacman_install() {
  (($#)) || return 0
  run_root pacman -S --needed --noconfirm "$@"
}

pacman_full_upgrade() {
  log "Полное обновление Omarchy/Arch"
  run_root pacman -Syu --noconfirm
}

yay_install_optional() {
  (($#)) || return 0
  if ! command_exists yay; then
    warn "yay не найден; пропускаю AUR: $*"
    return 0
  fi
  if "$DRY_RUN"; then
    run yay -S --needed --noconfirm "$@"
  elif ! yay -S --needed --noconfirm "$@"; then
    warn "Не удалось установить один или несколько AUR-пакетов: $*"
  fi
}

install_packages() {
  need_omarchy
  pacman_full_upgrade

  log "Установка официальных пакетов"
  local official=(
    base-devel git stow curl wget jq unzip zip rsync openssh gnupg python
    bash foot starship tmux neovim
    bat ripgrep fd eza lsd fastfetch btop htop
    wl-clipboard cliphist kitty man-db man-pages util-linux
    translate-shell sdcv zellij glow mpv yt-dlp fontconfig
    networkmanager bluez bluez-utils ttf-jetbrains-mono-nerd
    syncthing nfs-utils kubectl helm k9s github-cli
    googleworkspace-cli
  )
  pacman_install "${official[@]}"
  "$WITH_DOCKER" && pacman_install docker docker-compose docker-buildx

  log "Установка дополнительных пакетов из AUR"
  yay_install_optional mdcat
  command_exists ble.sh || [[ -r /usr/share/blesh/ble.sh ]] || yay_install_optional blesh-git
  yay_install_optional yandex-disk
  yay_install_optional amneziawg-dkms amneziawg-tools systemd-resolvconf
  yay_install_optional stardict-full-eng-rus stardict-full-rus-eng

  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
}

###############################################################################
# DOTFILES / STOW
###############################################################################

clone_or_update_dotfiles() {
  log "Dotfiles"
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    run git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  elif [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null)" ]]; then
    warn "$DOTFILES_DIR содержит локальные изменения; git pull пропущен."
  else
    run git -C "$DOTFILES_DIR" pull --ff-only
  fi
}

move_stow_conflicts() {
  local package=$1 backup_dir=$2 src rel target saved
  while IFS= read -r -d '' src; do
    rel=${src#"$DOTFILES_DIR/$package/"}
    target="$HOME/$rel"
    [[ -e "$target" || -L "$target" ]] || continue
    if [[ -L "$target" ]]; then
      if [[ "$(readlink -f "$target" 2>/dev/null || true)" == "$(readlink -f "$src" 2>/dev/null || true)" ]]; then
        continue
      fi
    elif [[ -f "$target" && -f "$src" ]] && cmp -s "$target" "$src"; then
      # Даже идентичный обычный файл нужно убрать: Stow должен создать symlink.
      :
    elif [[ -d "$target" ]]; then
      continue
    fi
    saved="$backup_dir/$rel"
    if "$DRY_RUN"; then
      printf '+ mkdir -p %q; mv -- %q %q\n' "$(dirname "$saved")" "$target" "$saved"
    else
      mkdir -p "$(dirname "$saved")"
      mv -- "$target" "$saved"
    fi
  done < <(find "$DOTFILES_DIR/$package" \( -type f -o -type l \) -print0)
}

setup_dotfiles() {
  clone_or_update_dotfiles
  command_exists stow || die "GNU Stow не найден."
  local backup_dir="$STATE_DIR/stow-backups/$(date +%Y%m%d-%H%M%S)"
  # Имена сверены с текущим репозиторием toxusa/dotfiles.
  local packages=(bash_omarchy foot_omarchy tmux starship batcat zellij vpn_omarchy hypr_omarchy)
  local package
  for package in "${packages[@]}"; do
    [[ -d "$DOTFILES_DIR/$package" ]] || { warn "Нет Stow-пакета: $package"; continue; }
    move_stow_conflicts "$package" "$backup_dir"
    if ! "$DRY_RUN"; then
      stow -n -v -d "$DOTFILES_DIR" -t "$HOME" --restow "$package" ||         die "Stow simulation обнаружила конфликт в пакете $package"
    else
      printf '+ stow -n -v -d %q -t %q --restow %q\n' "$DOTFILES_DIR" "$HOME" "$package"
    fi
    run stow -v -d "$DOTFILES_DIR" -t "$HOME" --restow "$package"
  done
  [[ -d "$backup_dir" ]] && log "Замещённые файлы сохранены в $backup_dir"
}

###############################################################################
# LOCALE, HOSTS, FSTAB, PLYMOUTH
###############################################################################

setup_locale() {
  log "Локаль: LANG=$LOCALE_LANG, LC_TIME=$LOCALE_TIME"
  backup_file_once /etc/locale.gen
  [[ -e /etc/locale.conf ]] && backup_file_once /etc/locale.conf
  local l escaped
  for l in "$LOCALE_LANG" "$LOCALE_TIME"; do
    escaped=${l//./\.}
    if grep -qE "^#[[:space:]]*${escaped}[[:space:]]+UTF-8" /etc/locale.gen; then
      run_root sed -i -E "s/^#[[:space:]]*(${escaped}[[:space:]]+UTF-8)[[:space:]]*$/\1/" /etc/locale.gen
    elif ! grep -qE "^${escaped}[[:space:]]+UTF-8" /etc/locale.gen; then
      if "$DRY_RUN"; then
        printf '+ append %q to /etc/locale.gen\n' "$l UTF-8"
      else
        printf '%s UTF-8\n' "$l" | sudo tee -a /etc/locale.gen >/dev/null
      fi
    fi
  done
  run_root locale-gen
  run_root localectl set-locale "LANG=$LOCALE_LANG" "LC_TIME=$LOCALE_TIME"
  mkdir -p "$HOME/.config/environment.d"
  if ! "$DRY_RUN"; then
    printf 'LANG=%s\nLC_TIME=%s\n' "$LOCALE_LANG" "$LOCALE_TIME" >"$HOME/.config/environment.d/10-locale.conf"
  else
    echo "+ write $HOME/.config/environment.d/10-locale.conf"
  fi
  local fw base
  fw=$(LC_TIME="$LOCALE_TIME" locale first_weekday 2>/dev/null || true)
  base=$(LC_TIME="$LOCALE_TIME" locale week-1stday 2>/dev/null || true)
  [[ -n "$fw" && -n "$base" ]] && echo "Первый день недели: $(date -d "$base +$((fw-1)) days" +%A)"
  warn "Для графической сессии локаль окончательно применится после logout/login."
}

setup_hosts() {
  log "/etc/hosts"
  "$DRY_RUN" && { echo "+ update managed Homelab block in /etc/hosts"; return 0; }
  sudo python3 - <<'PY'
from pathlib import Path
from datetime import datetime
p = Path('/etc/hosts')
begin = '# BEGIN OMARCHY-SETUP HOMELAB'
end = '# END OMARCHY-SETUP HOMELAB'
entries = [
'192.168.1.200 gitlab.homelab.local',
'192.168.1.200 registry.homelab.local',
'192.168.1.200 minio.homelab.local',
'192.168.1.200 test-version.homelab.local',
'195.14.48.122 grafana.homelab.local',
'195.14.48.122 prometheus.homelab.local',
'192.168.1.221 argocd.homelab.local',
'192.168.1.221 dashboard.homelab.local',
'192.168.1.221 traefik.homelab.local',
]
hosts = {line.split()[1] for line in entries}
text = p.read_text()
Path(str(p)+'.bak-omarchy-setup').write_text(text)
out, managed = [], False
for line in text.splitlines():
    if line.strip() == begin:
        managed = True
        continue
    if line.strip() == end:
        managed = False
        continue
    if managed:
        continue
    fields = line.split()
    if not line.lstrip().startswith('#') and any(h in fields[1:] for h in hosts):
        continue
    out.append(line)
while out and not out[-1].strip():
    out.pop()
out += ['', begin, '# Homelab: local DNS overrides', *entries[:4], '',
        '# Homelab monitoring: external address', *entries[4:6], '',
        '# Homelab internal services', *entries[6:], end, '']
p.write_text('\n'.join(out))
PY
}

setup_fstab() {
  log "NFS: $NFS_SOURCE -> $NFS_TARGET"
  run_root install -d -m 755 "$NFS_TARGET"
  "$DRY_RUN" && { echo "+ update managed NFS entry in /etc/fstab"; return 0; }
  sudo env NFS_SOURCE="$NFS_SOURCE" NFS_TARGET="$NFS_TARGET" python3 - <<'PY'
from pathlib import Path
import os
p=Path('/etc/fstab')
src=os.environ['NFS_SOURCE']; target=os.environ['NFS_TARGET']
entry=f'{src} {target} nfs user,noauto,rw 0 0'
text=p.read_text()
Path(str(p)+'.bak-omarchy-setup').write_text(text)
out=[]
for line in text.splitlines():
    f=line.split()
    if len(f) >= 2 and not line.lstrip().startswith('#') and (f[0] == src or f[1] == target):
        continue
    out.append(line)
while out and not out[-1].strip(): out.pop()
out += ['', '# Managed by omarchy-setup', entry, '']
p.write_text('\n'.join(out))
PY
  sudo systemctl daemon-reload
  if "$WITH_MOUNT" && ! findmnt -rn "$NFS_TARGET" >/dev/null 2>&1; then
    if ! mount "$NFS_TARGET"; then warn "NFS пока не смонтирован; позже: mount '$NFS_TARGET'"; fi
  fi
}

hide_plymouth_logo() {
  "$WITH_PLYMOUTH" || return 0
  local logo=/usr/share/plymouth/themes/omarchy/logo.png
  [[ -f "$logo" ]] || { warn "Plymouth logo не найден: $logo"; return 0; }
  log "Прозрачный логотип Plymouth"
  "$DRY_RUN" && { echo "+ replace $logo with transparent 1x1 PNG; limine-update"; return 0; }
  sudo install -d -m 700 /var/lib/omarchy-setup
  [[ -f /var/lib/omarchy-setup/plymouth-logo.original.png ]] || \
    sudo cp -a "$logo" /var/lib/omarchy-setup/plymouth-logo.original.png
  local tmp; tmp=$(mktemp)
  python3 - "$tmp" <<'PY'
import zlib, struct, sys
def chunk(t, d):
    c = struct.pack('>I', len(d)) + t + d
    return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
raw = b'\x00\x00\x00\x00\x00'
png = (b'\x89PNG\r\n\x1a\n' +
       chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0)) +
       chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
open(sys.argv[1], 'wb').write(png)
PY
  if cmp -s "$tmp" "$logo"; then
    rm -f "$tmp"
    ok "Логотип уже прозрачный"
  else
    sudo install -m 644 "$tmp" "$logo"
    rm -f "$tmp"
    if command_exists limine-update; then sudo limine-update; else warn "limine-update не найден"; fi
  fi
}

###############################################################################
# GCLOUD, GWS, OMARCHY PLUGINS
###############################################################################

install_gcloud() {
  if command_exists gcloud; then
    ok "gcloud уже установлен: $(gcloud --version | head -1)"
    return 0
  fi
  [[ "$(uname -m)" == x86_64 ]] || { warn "Автоустановка gcloud рассчитана на x86_64"; return 0; }
  log "Google Cloud CLI -> $GCLOUD_DIR"
  "$DRY_RUN" && { echo "+ download $GCLOUD_URL and install to $GCLOUD_DIR"; return 0; }
  local tmp archive actual
  tmp=$(mktemp -d); archive="$tmp/gcloud.tar.gz"
  curl -fL --retry 3 -o "$archive" "$GCLOUD_URL"
  actual=$(sha256sum "$archive" | awk '{print $1}')
  if [[ -n "${GCLOUD_SHA256:-}" && "$actual" != "$GCLOUD_SHA256" ]]; then
    rm -rf "$tmp"; die "SHA256 gcloud не совпал: $actual"
  elif [[ -z "${GCLOUD_SHA256:-}" ]]; then
    warn "GCLOUD_SHA256 не задан; фактический SHA256: $actual"
  fi
  tar -tzf "$archive" >/dev/null
  tar -xzf "$archive" -C "$tmp"
  rm -rf "$GCLOUD_DIR"
  mkdir -p "$(dirname "$GCLOUD_DIR")"
  mv "$tmp/google-cloud-sdk" "$GCLOUD_DIR"
  "$GCLOUD_DIR/install.sh" --quiet --usage-reporting=false --path-update=false --command-completion=false
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$GCLOUD_DIR/bin/gcloud" "$HOME/.local/bin/gcloud"
  rm -rf "$tmp"
}

ensure_plugin() {
  local id=$1 url=$2 dir="$HOME/.config/omarchy/plugins/$1"
  if [[ -d "$dir" ]]; then
    log "Плагин уже установлен: $id"
    run omarchy plugin enable "$id" || warn "Не удалось включить $id автоматически"
  else
    log "Установка плагина: $id"
    run omarchy plugin add "$url" --enable --yes
  fi
}

patch_calendar_shell_json() {
  [[ -f "$SHELL_JSON" ]] || { warn "$SHELL_JSON не найден; календарь не помещён в bar."; return 0; }
  "$DRY_RUN" && { echo "+ idempotently patch $SHELL_JSON for $PLUGIN_CAL_ID"; return 0; }
  SHELL_JSON="$SHELL_JSON" PLUGIN_ID="$PLUGIN_CAL_ID" python3 - <<'PY'
import json, os, shutil, datetime
p, pid = os.environ['SHELL_JSON'], os.environ['PLUGIN_ID']
with open(p, encoding='utf-8') as f: d=json.load(f)
old=json.dumps(d, sort_keys=True, ensure_ascii=False)
bar=d.setdefault('bar', {})
layout=bar.setdefault('layout', {})
center=layout.setdefault('center', [])
def ident(x): return x.get('id') if isinstance(x, dict) else x
center[:] = [x for x in center if ident(x) not in ('omarchy.clock', pid)]
center.append({'id': pid, 'format': 'dddd HH:mm', 'eventTimeFormat': 'HH:mm'})
bar['centerAnchor']=pid
new=json.dumps(d, sort_keys=True, ensure_ascii=False)
if new != old:
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    shutil.copy2(p, f'{p}.bak.{stamp}')
    with open(p, 'w', encoding='utf-8') as f:
        json.dump(d, f, indent=2, ensure_ascii=False); f.write('\n')
PY
}

setup_plugins() {
  need_omarchy
  if ! pgrep -x omarchy-shell >/dev/null 2>&1 && [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    warn "Omarchy shell/Hyprland не запущен. Установку плагинов лучше повторить из графической сессии."
  fi
  ensure_plugin "$PLUGIN_ALTTAB_ID" "$PLUGIN_ALTTAB_URL"
  ensure_plugin "$PLUGIN_CAL_ID" "$PLUGIN_CAL_URL"
  patch_calendar_shell_json
  run omarchy restart shell || warn "Shell не перезапущен; сделай это после завершения."
}

calendar_auth() {
  need_omarchy
  command_exists gws || die "gws не найден. Выполни setup."
  local setup="$HOME/.config/omarchy/plugins/$PLUGIN_CAL_ID/sync/setup"
  [[ -x "$setup" ]] || die "Не найден мастер: $setup"
  cat <<'EOF'
Мастер создаст проект, включит Calendar API и установит systemd timer.
В Cloud Console вручную понадобятся:
  1) OAuth consent screen;
  2) Data Access: calendar.readonly (+ calendar.events для записи);
  3) публикация приложения (Testing-токен истекает через 7 дней);
  4) OAuth client типа Desktop app и client_secret.json.
EOF
  if [[ -t 0 ]]; then
    read -rp "Запустить интерактивный мастер с правом записи? [y/N] " a
    [[ "$a" =~ ^[Yy]$ ]] || { warn "Пропущено. Позже: '$setup' --write"; return 0; }
  fi
  GWS="$(command -v gws)" "$setup" --write
}

###############################################################################
# DOCKER, SERVICES, THINKPAD
###############################################################################

setup_base_services() {
  log "Базовые системные службы"
  run_root systemctl enable --now NetworkManager.service
  # Bluetooth доступен на всех машинах; режим AutoEnable меняется только на ThinkPad.
  run_root systemctl enable bluetooth.service
}

setup_docker() {
  "$WITH_DOCKER" || return 0
  log "Docker socket activation"
  run_root groupadd -f docker
  run_root usermod -aG docker "$USER"
  run_root systemctl disable docker.service 2>/dev/null || true
  run_root systemctl enable --now docker.socket
  warn "Для членства в группе docker нужен полный logout/login. Группа docker даёт root-подобные права."
}

write_yandex_unit() {
  command_exists yandex-disk || return 0
  local unit="$HOME/.config/systemd/user/yandex-disk.service"
  [[ -f "$unit" ]] && return 0
  mkdir -p "$(dirname "$unit")"
  write_if_changed "$unit" 600 <<'EOF'
[Unit]
Description=Yandex.Disk synchronization
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/usr/bin/yandex-disk start
ExecStop=/usr/bin/yandex-disk stop
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
}

setup_services() {
  log "Пользовательские службы"
  if [[ -f "$HOME/.local/state/syncthing/config.xml" || -f "$HOME/.config/syncthing/config.xml" ]]; then
    run systemctl --user enable --now syncthing.service
  else
    warn "Syncthing установлен, но identity/config ещё нет: служба не запущена."
  fi
  write_yandex_unit
  if command_exists yandex-disk && [[ -f "$HOME/.config/yandex-disk/passwd" ]]; then
    run systemctl --user daemon-reload
    run systemctl --user enable --now yandex-disk.service
  elif command_exists yandex-disk; then
    warn "Yandex.Disk не авторизован. Выполни yandex-disk setup; затем enable --now yandex-disk.service."
  fi
  if [[ -f "$HOME/.config/systemd/user/omarchy-calendar-sync.timer" ]]; then
    run systemctl --user daemon-reload
    run systemctl --user enable --now omarchy-calendar-sync.timer
  fi
}

setup_thinkpad() {
  "$WITH_THINKPAD" || return 0
  local model
  model=$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)
  if [[ "$model" != *"ThinkPad X1 Carbon Gen 9"* ]]; then
    warn "Модель '$model' не X1 Carbon Gen 9; аппаратный блок пропущен."
    return 0
  fi
  log "ThinkPad X1 Carbon Gen 9"
  pacman_install modemmanager libmbim libqmi mobile-broadband-provider-info fprintd bluez bluez-utils
  run_root systemctl enable --now ModemManager.service bluetooth.service
  if [[ -e /usr/share/ModemManager/fcc-unlock.available.d/1eac:1001 ]]; then
    run_root install -d /etc/ModemManager/fcc-unlock.d
    run_root ln -sfn /usr/share/ModemManager/fcc-unlock.available.d/1eac:1001 /etc/ModemManager/fcc-unlock.d/1eac:1001
    run_root systemctl restart ModemManager.service
  fi

  if [[ -f /etc/bluetooth/main.conf ]]; then
    backup_file_once /etc/bluetooth/main.conf
    if "$DRY_RUN"; then
      echo "+ ensure AutoEnable=false in [Policy] of /etc/bluetooth/main.conf"
    else
      sudo python3 - <<'PYBT'
from pathlib import Path
p = Path('/etc/bluetooth/main.conf')
lines = p.read_text().splitlines()
out, in_policy, found = [], False, False
has_policy = any(line.strip() == '[Policy]' for line in lines)
for line in lines:
    stripped = line.strip()
    if stripped.startswith('[') and stripped.endswith(']'):
        if in_policy and not found:
            out.append('AutoEnable=false')
        in_policy = stripped == '[Policy]'
    if in_policy and stripped.lstrip('#').strip().startswith('AutoEnable='):
        if not found:
            out.append('AutoEnable=false'); found = True
        continue
    out.append(line)
if in_policy and not found:
    out.append('AutoEnable=false')
if not has_policy:
    out.extend(['', '[Policy]', 'AutoEnable=false'])
p.write_text('\n'.join(out) + '\n')
PYBT
    fi
    run_root systemctl restart bluetooth.service
    run_root rfkill unblock bluetooth || true
  fi

  if command_exists nmcli; then
    nmcli connection modify "Omarchy Cellular" connection.autoconnect no 2>/dev/null || true
    nmcli connection modify "MTS" connection.autoconnect no 2>/dev/null || true
    nmcli radio wwan off || true
  fi

  if "$WITH_TLP"; then
    pacman_install tlp
    run_root systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
    run_root systemctl enable --now tlp.service
    if ! "$DRY_RUN"; then
      sudo install -d /etc/tlp.d
      printf '%s\n' 'START_CHARGE_THRESH_BAT0=75' 'STOP_CHARGE_THRESH_BAT0=80' | \
        sudo tee /etc/tlp.d/10-thinkpad-battery.conf >/dev/null
      sudo tlp start || true
    fi
  fi
  warn "Fingerprint enrolment остаётся интерактивным: fprintd-enroll -f right-index-finger"
  warn "Проверь UUID LTE в ~/.local/bin/wwan-toggle командой nmcli connection show."
}

###############################################################################
# RESTORE
###############################################################################

resolve_backup_dir() {
  local p=$1
  [[ -d "$p" ]] || die "Нет каталога бэкапа: $p"
  [[ -f "$p/private-home.tar.gz.gpg" ]] || die "Нет $p/private-home.tar.gz.gpg"
  printf '%s\n' "$(cd "$p" && pwd -P)"
}

restore_item() {
  local src=$1 dest=$2 rescue=$3 rel=$4
  [[ -e "$src" || -L "$src" ]] || return 0
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$(dirname "$rescue/$rel")"
    mv -- "$dest" "$rescue/$rel"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a -- "$src" "$dest"
}

ensure_github_ssh() {
  local key="$HOME/.ssh/github_toxusa" config="$HOME/.ssh/config"
  [[ -f "$key" ]] || return 0
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  touch "$config"; chmod 600 "$config"
  if ! awk 'BEGIN{x=0} /^[[:space:]]*Host[[:space:]]+github\.com([[:space:]]|$)/{x=1} END{exit !x}' "$config"; then
    cat >>"$config" <<'EOF'

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_toxusa
  IdentitiesOnly yes
EOF
  fi
}

restore_backup() {
  need_regular_user
  [[ -n "$BACKUP_FROM" ]] || die "Укажи --from BACKUP_DIR"
  local dir archive checksum stamp restored_stamp tmp tarball stage rescue
  dir=$(resolve_backup_dir "$BACKUP_FROM")
  archive="$dir/private-home.tar.gz.gpg"
  if [[ -f "$dir/SHA256SUMS" ]]; then (cd "$dir" && sha256sum -c SHA256SUMS); fi
  checksum=$(sha256sum "$archive" | awk '{print $1}')
  stamp="$STATE_DIR/restored-$checksum"
  if [[ -f "$stamp" && "$FORCE" != true ]]; then
    ok "Этот бэкап уже восстановлен: $dir"
    return 0
  fi

  systemctl --user stop syncthing.service 2>/dev/null || true
  if pgrep -x zen-browser >/dev/null 2>&1 || pgrep -x zen >/dev/null 2>&1; then
    die "Закрой Zen Browser и повтори restore."
  fi

  tmp=$(mktemp -d); tarball="$tmp/private.tar.gz"; stage="$tmp/stage"
  trap 'rm -rf "${tmp:-}"' RETURN
  umask 077
  log "Расшифровка; GPG запросит пароль"
  gpg --decrypt --output "$tarball" "$archive"
  tar -tzf "$tarball" >/dev/null
  mkdir -p "$stage"
  tar -xzf "$tarball" --no-same-owner --no-same-permissions -C "$stage"

  rescue="$STATE_DIR/pre-restore-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$rescue"
  log "Восстановление приватных данных"
  local rel src original_path old_home
  local -a restored_paths=()
  old_home=$(cat "$stage/BACKUP_HOME" 2>/dev/null || true)
  [[ -n "$old_home" ]] || old_home="/home/${USER}"
  [[ -f "$stage/MANIFEST.paths" ]] || die "В архиве нет MANIFEST.paths"
  while IFS= read -r original_path; do
    [[ -n "$original_path" ]] || continue
    local skip_path=false parent
    for parent in "${restored_paths[@]:-}"; do
      [[ "$original_path" == "$parent"/* ]] && { skip_path=true; break; }
    done
    "$skip_path" && continue
    case "$original_path" in
      "$old_home"/*)
        rel=${original_path#"$old_home"/}
        src="$stage/home/$rel"
        restore_item "$src" "$HOME/$rel" "$rescue" "$rel"
        restored_paths+=("$original_path")
        ;;
      /etc/*)
        # Системные файлы не возвращаем вслепую на другую ОС/установку.
        # Известные hosts/fstab/locale применяются идемпотентными setup-функциями.
        ;;
      *) warn "Неизвестный путь в manifest, пропускаю: $original_path" ;;
    esac
  done < <(awk '{ print length, $0 }' "$stage/MANIFEST.paths" | sort -n | cut -d' ' -f2-)
  if [[ -f "$stage/system-root-readable.tar.gz" ]]; then
    install -m 600 "$stage/system-root-readable.tar.gz" "$rescue/system-root-readable.tar.gz"
    warn "Root-конфиги сохранены для ручного разбора: $rescue/system-root-readable.tar.gz"
  fi

  [[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh"
  if [[ -d "$HOME/.ssh" ]]; then
    find "$HOME/.ssh" -type f -name '*.pub' -exec chmod 644 {} +
    find "$HOME/.ssh" -type f ! -name '*.pub' ! -name 'known_hosts*' -exec chmod 600 {} +
    chmod 644 "$HOME/.ssh"/known_hosts* 2>/dev/null || true
  fi
  [[ -d "$HOME/.gnupg" ]] && chmod 700 "$HOME/.gnupg"
  [[ -d "$HOME/.kube" ]] && { chmod 700 "$HOME/.kube"; find "$HOME/.kube" -maxdepth 1 -type f -exec chmod 600 {} +; }
  ensure_github_ssh
  fc-cache -f 2>/dev/null || true
  mkdir -p "$STATE_DIR"; printf '%s\n' "$dir" >"$stamp"
  ok "Данные восстановлены. Замещённое сохранено в $rescue"
  warn "В Zen при необходимости открой about:profiles и выбери старый профиль по умолчанию."
}

###############################################################################
# MAIN SETUP / VERIFY
###############################################################################

setup_all() {
  need_regular_user
  need_omarchy
  install_packages
  setup_base_services
  setup_dotfiles
  setup_locale
  setup_hosts
  setup_fstab
  install_gcloud
  setup_plugins
  setup_docker
  setup_thinkpad
  hide_plymouth_logo
  [[ -n "$BACKUP_FROM" ]] && restore_backup
  setup_services
  "$WITH_CALENDAR_AUTH" && calendar_auth
  log "Настройка завершена"
  warn "Сделай logout/login (локаль, группа docker), затем запусти: $0 verify"
}

verify() {
  log "Базовые команды"
  local commands=(git stow gh bash foot starship tmux nvim fd eza lsd fastfetch btop htop mdcat trans sdcv zellij kitten mpv bat rg wl-copy cliphist rsync ssh docker syncthing kubectl helm k9s gcloud gws)
  local c
  for c in "${commands[@]}"; do
    if command_exists "$c"; then printf '  OK   %-12s %s\n' "$c" "$(command -v "$c")"; else printf '  MISS %s\n' "$c"; fi
  done

  log "Dotfiles и Hyprland"
  git -C "$DOTFILES_DIR" status --short 2>/dev/null || true
  local link
  for link in "$HOME/.bashrc" "$HOME/.config/foot" "$HOME/.config/tmux" \
              "$HOME/.config/starship.toml" "$HOME/.config/hypr"; do
    printf '  %-32s -> %s\n' "$link" "$(readlink -f "$link" 2>/dev/null || echo 'NOT FOUND')"
  done
  hyprctl configerrors 2>/dev/null || true
  if command_exists ble-face; then
    ble-face 2>/dev/null | grep -E 'auto_complete=|syntax_error=' || true
  fi

  log "Службы"
  systemctl is-enabled NetworkManager.service bluetooth.service 2>/dev/null || true
  systemctl is-active NetworkManager.service bluetooth.service 2>/dev/null || true
  systemctl --user is-enabled syncthing.service 2>/dev/null || true
  systemctl --user is-active syncthing.service 2>/dev/null || true
  systemctl is-enabled docker.socket 2>/dev/null || true
  systemctl is-active docker.socket 2>/dev/null || true
  systemctl --user list-timers omarchy-calendar-sync.timer --no-pager 2>/dev/null || true

  log "Сеть и хранилище"
  getent hosts gitlab.homelab.local grafana.homelab.local argocd.homelab.local || true
  findmnt "$NFS_TARGET" || true

  log "Конфиги"
  kubectl config get-contexts -o name 2>/dev/null || true
  helm env 2>/dev/null | grep '^HELM_REPOSITORY_CONFIG=' || true
  sdcv --list-dicts 2>/dev/null || true
  ssh -G github.com 2>/dev/null | grep -Ei '^(hostname|user|identityfile|identitiesonly) ' || true

  if [[ -f "$HOME/.ssh/github_toxusa" ]]; then
    echo "GitHub SSH: проверь вручную: ssh -T git@github.com"
  fi
  if [[ "$WITH_THINKPAD" == true || -e /sys/class/net/wwan0mbim0 ]]; then
    log "ThinkPad"
    rfkill list bluetooth 2>/dev/null || true
    bluetoothctl show 2>/dev/null | grep -i powered || true
    mmcli -L 2>/dev/null || true
    nmcli radio 2>/dev/null || true
  fi
}

main() {
  need_regular_user
  local action=${1:-}
  [[ -n "$action" ]] || { usage; exit 2; }
  shift || true
  while (($#)); do
    case "$1" in
      --from) [[ $# -ge 2 ]] || die "--from требует путь"; BACKUP_FROM=$2; shift ;;
      --backup-root) [[ $# -ge 2 ]] || die "--backup-root требует путь"; BACKUP_ROOT=$2; shift ;;
      --thinkpad) WITH_THINKPAD=true ;;
      --with-tlp) WITH_THINKPAD=true; WITH_TLP=true ;;
      --skip-docker) WITH_DOCKER=false ;;
      --skip-plymouth) WITH_PLYMOUTH=false ;;
      --skip-mount) WITH_MOUNT=false ;;
      --calendar-auth) WITH_CALENDAR_AUTH=true ;;
      --force) FORCE=true ;;
      --dry-run) DRY_RUN=true ;;
      -h|--help) usage; exit 0 ;;
      *) die "Неизвестный аргумент: $1" ;;
    esac
    shift
  done

  mkdir -p "$STATE_DIR"
  export PATH="$HOME/.local/bin:$PATH"
  case "$action" in
    backup) backup_home ;;
    setup) setup_all ;;
    restore) restore_backup; setup_services ;;
    all) setup_all ;;
    calendar-auth) calendar_auth ;;
    verify) verify ;;
    help|-h|--help) usage ;;
    *) die "Неизвестное действие: $action" ;;
  esac
}

main "$@"
