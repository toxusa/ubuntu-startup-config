#!/usr/bin/env bash
set -euo pipefail

app_name="zen"
archive_url="https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz"

install_root="$HOME/.local/opt"
install_dir="$install_root/$app_name"

local_bin="$HOME/.local/bin"
desktop_dir="$HOME/.local/share/applications"
desktop_file="$desktop_dir/zen-browser.desktop"

tmp_archive="$(mktemp /tmp/zen.XXXXXX.tar.xz)"
tmp_dir="$(mktemp -d)"

echo "==> Downloading Zen Browser tarball..."
curl -L -o "$tmp_archive" "$archive_url"

echo "==> Extracting archive..."
tar -xvJf "$tmp_archive" -C "$tmp_dir"

# В tarball'е корневая папка называется 'zen'
if [ ! -d "$tmp_dir/zen" ]; then
  echo "Error: extracted archive does not contain 'zen' directory"
  exit 1
fi

echo "==> Removing old installation (if any)..."
rm -rf "$install_dir"

echo "==> Moving Zen to $install_dir"
mkdir -p "$install_root"
mv "$tmp_dir/zen" "$install_dir"

rm -f "$tmp_archive"
rm -rf "$tmp_dir"

executable_path="$install_dir/zen"
icon_path="$install_dir/browser/chrome/icons/default/default128.png"

echo "==> Creating symlink in $local_bin"
mkdir -p "$local_bin"
ln -sf "$executable_path" "$local_bin/$app_name"

echo "==> Creating .desktop file in $desktop_dir"
mkdir -p "$desktop_dir"

cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Zen Browser
Comment=Zen web browser
Exec=$executable_path %u
Icon=$icon_path
Terminal=false
Categories=Network;WebBrowser;
StartupWMClass=zen


[Desktop Entry]
Type=Application
Name=Zen Browser
Comment=Zen web browser
Exec=$executable_path %u
Icon=$icon_path
Terminal=false
Categories=Network;WebBrowser;
StartupWMClass=zen
Actions=new-window;new-private-window;profilemanager;

[Desktop Action new-window]
Name=New Window
Name[ru]=Новое окно
Exec=$executable_path --new-window %u

[Desktop Action new-private-window]
Name=New Private Window
Name[ru]=Новое приватное окно
Exec=$executable_path --private-window %u

[Desktop Action profilemanager]
Name=Open Profile Manager
Name[ru]=Открыть менеджер профилей
Exec=$executable_path --ProfileManager %u

EOF

chmod +x "$desktop_file"

echo "==> Installation finished."
echo "Запуск из терминала:  zen"
echo "Запуск из GNOME: найдите 'Zen Browser' в меню приложений и закрепите в доке."

