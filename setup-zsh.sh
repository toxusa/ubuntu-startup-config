#!/bin/bash
# Сохраните как setup-zsh.sh и запустите: chmod +x setup-zsh.sh && ./setup-zsh.sh

echo "🚀 Установка красивого ZSH..."

# Установка ZSH
sudo apt update && sudo apt install -y zsh git curl wget fonts-powerline lsd

# Установка шрифтов
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf -O ~/.local/share/fonts/MesloLGS_NF_Regular.ttf
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf -O ~/.local/share/fonts/MesloLGS_NF_Bold.ttf
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf -O ~/.local/share/fonts/MesloLGS_NF_Italic.ttf
wget https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf -O ~/.local/share/fonts/MesloLGS_NF_Bold_Italic.ttf
wget https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf -O ~/.local/share/fonts/PowerlineSymbols.otf

fc-cache -vf ~/.local/share/fonts/

# Установка Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Установка Powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Установка плагинов
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Базовая конфигурация
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    docker
    zsh-autosuggestions
    zsh-syntax-highlighting
    history
    sudo
)

source $ZSH/oh-my-zsh.sh

# Aliases
alias ll='lsd -alF'
alias la='lsd -A'
alias ls='lsd'
EOF

source ~/.zshrc

echo "✅ Готово! Перезапустите сессию: exec zsh."
