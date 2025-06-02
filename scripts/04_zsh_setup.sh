#!/bin/bash

# 设置日志文件路径
BASE_DIR="/tmp/deb-init"
LOG_FILE="$BASE_DIR/deb-init.log"

SCRIPT_DIR_ZSH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_ZSH/common_functions.sh"

# 确保日志输出到文件
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_info "阶段 1.1.7: Zsh 和 Oh My Zsh 配置开始..."

# 确认安装 zsh、git 和 lua5.4
ensure_packages zsh git lua5.4

# 设置 Oh My Zsh 安装目录
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSHRC_PATH="$HOME/.zshrc"

# 1. 安装 Oh My Zsh
log_info "检查 Oh My Zsh 安装情况..."
if [ ! -d "$OH_MY_ZSH_DIR" ]; then
    log_info "Oh My Zsh 未安装. 开始安装..."
    OHMYZSH_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    OHMYZSH_INSTALL_SCRIPT_PATH="/tmp/ohmyzsh_install.sh"

    # 下载安装脚本
    if ! curl -fsSL "$OHMYZSH_INSTALL_SCRIPT_URL" -o "$OHMYZSH_INSTALL_SCRIPT_PATH"; then
        log_error "下载 Oh My Zsh 安装脚本失败. URL: $OHMYZSH_INSTALL_SCRIPT_URL"
        exit 1
    fi

    if sh "$OHMYZSH_INSTALL_SCRIPT_PATH" --unattended --keep-zshrc; then
        log_info "Oh My Zsh 安装成功."
        rm -f "$OHMYZSH_INSTALL_SCRIPT_PATH"
    else
        log_error "Oh My Zsh 安装失败."
        rm -f "$OHMYZSH_INSTALL_SCRIPT_PATH"
        exit 1
    fi
else
    log_info "Oh My Zsh 已安装在 $OH_MY_ZSH_DIR."
fi

# 2. 定义ZSH_CUSTOM路径
ZSH_CUSTOM="$OH_MY_ZSH_DIR/custom"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
mkdir -p "$PLUGINS_DIR"

# 3. 安装插件
log_info "安装 Zsh 插件..."

# evalcache
EVALCACHE_DIR="$PLUGINS_DIR/evalcache"
if [ ! -d "$EVALCACHE_DIR" ]; then
    log_info "安装插件: evalcache..."
    execute_command "克隆 evalcache" git clone https://github.com/mroth/evalcache "$EVALCACHE_DIR"
else
    log_info "插件 evalcache 已存在."
fi

# zsh-syntax-highlighting
SYNTAX_HIGHLIGHTING_DIR="$PLUGINS_DIR/zsh-syntax-highlighting"
if [ ! -d "$SYNTAX_HIGHLIGHTING_DIR" ]; then
    log_info "安装插件: zsh-syntax-highlighting..."
    execute_command "克隆 zsh-syntax-highlighting" git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_HIGHLIGHTING_DIR"
else
    log_info "插件 zsh-syntax-highlighting 已存在."
fi

# zsh-autosuggestions
AUTOSUGGESTIONS_DIR="$PLUGINS_DIR/zsh-autosuggestions"
if [ ! -d "$AUTOSUGGESTIONS_DIR" ]; then
    log_info "安装插件: zsh-autosuggestions..."
    execute_command "克隆 zsh-autosuggestions" git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGESTIONS_DIR"
else
    log_info "插件 zsh-autosuggestions 已存在."
fi

# z.lua
ZLUA_DIR="$PLUGINS_DIR/z.lua"
if [ ! -d "$ZLUA_DIR" ]; then
    log_info "安装插件: z.lua..."
    execute_command "克隆 z.lua" git clone https://github.com/skywind3000/z.lua.git "$ZLUA_DIR"
else
    log_info "插件 z.lua 已存在."
fi

# 4. 更新 .zshrc
ZSHRC_GIST_URL="https://gist.github.com/JiangBeta/1ccc2a827ac30cf7bf4dfc3d8830db54/raw/886b8e6dd1ad2fecfb33068e324fa378906abca8/.zshrc"
log_info "下载自定义 .zshrc 文件..."

# 备份现有的 .zshrc
if [ -f "$ZSHRC_PATH" ]; then
    cp "$ZSHRC_PATH" "${ZSHRC_PATH}.backup_$(date +%Y%m%d%H%M%S)"
    log_info "已备份 $ZSHRC_PATH"
fi

# 下载和修改 .zshrc
if curl -fsSL "$ZSHRC_GIST_URL" -o "$ZSHRC_PATH"; then
    log_info ".zshrc 文件已下载."
    
    # 替换 ZSH 路径
    sed -i "s|^export ZSH=.*|export ZSH=~/.oh-my-zsh|" "$ZSHRC_PATH"
    sed -i "s|^export ZSH_CACHE_DIR=.*|export ZSH_CACHE_DIR=~/.oh-my-zsh/cache|" "$ZSHRC_PATH"
    
    # 添加 z.lua 初始化
    echo "" >> "$ZSHRC_PATH"
    echo "# z.lua 配置" >> "$ZSHRC_PATH"
    echo 'eval "$(lua ~/.oh-my-zsh/custom/plugins/z.lua/z.lua --init zsh once enhanced)"' >> "$ZSHRC_PATH"
    
    log_info ".zshrc 文件已更新."
else
    log_error "下载 .zshrc 文件失败. URL: $ZSHRC_GIST_URL"
    log_warn "如果之前有备份，可以从备份恢复。"
fi

# 5. 设置Zsh为默认Shell
ZSH_PATH=$(which zsh)
if [ -n "$ZSH_PATH" ]; then
    CURRENT_SHELL=$(getent passwd "$(whoami)" | cut -d: -f7)
    if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
        log_info "尝试将 Zsh 设置为当前用户的默认 shell..."
        if chsh -s "$ZSH_PATH"; then
            log_info "Zsh 已成功设置为默认 shell."
        else
            log_warn "设置 Zsh 为默认 shell 失败. 您可能需要手动执行: chsh -s $ZSH_PATH"
        fi
    else
        log_info "Zsh已经是当前用户的默认shell."
    fi
else
    log_warn "未找到 zsh 程序, 无法设置为默认 shell."
fi

log_info "Zsh 和 Oh My Zsh 配置完成."
zsh -c "source $ZSHRC_PATH"

# 恢复标准输出
exec 1>&3 2>&4