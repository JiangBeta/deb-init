#!/bin/bash

SCRIPT_DIR_VIM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_VIM/common_functions.sh"

log_info "阶段 1.1.6: Vim 配置开始..."

# 确认安装 vim
ensure_packages vim

VIMRC_URL="https://raw.githubusercontent.com/wklken/vim-for-server/master/vimrc"
VIMRC_PATH="$HOME/.vimrc"

log_info "拉取 Vim 配置文件到 $VIMRC_PATH..."
# 如果脚本以sudo执行，这里的 $HOME 是 /root
# 如果脚本不以sudo执行，但此函数被 main.sh 中以 sudo 调用，则 $HOME 可能是执行 sudo 的用户的家目录
# 为了确保是当前“操作目标用户”（通常是root或执行脚本的用户），我们这样处理：
TARGET_VIMRC_PATH=""
if [ "$SUDO_CMD" == "sudo" ] && [ "$(id -u)" -ne 0 ]; then
    # 如果是以非root用户通过sudo执行，我们假设配置是给当前用户的
    TARGET_VIMRC_PATH="$HOME/.vimrc"
    log_info "为当前用户 $USER 配置 Vim ($TARGET_VIMRC_PATH)."
    # 下载时不能用sudo，因为要写入 $HOME
    if curl -fsSL "$VIMRC_URL" -o "$TARGET_VIMRC_PATH"; then
        log_info "Vim 配置文件下载成功到 $TARGET_VIMRC_PATH."
    else
        log_error "下载 Vim 配置文件失败. URL: $VIMRC_URL"
    fi
elif [ "$(id -u)" -eq 0 ]; then
    # 如果是root用户直接执行
    TARGET_VIMRC_PATH="/root/.vimrc"
    log_info "为 root 用户配置 Vim ($TARGET_VIMRC_PATH)."
    if curl -fsSL "$VIMRC_URL" -o "$TARGET_VIMRC_PATH"; then
        log_info "Vim 配置文件下载成功到 $TARGET_VIMRC_PATH."
    else
        log_error "下载 Vim 配置文件失败. URL: $VIMRC_URL"
    fi
else
    log_warn "无法确定 Vim 配置的目标用户家目录。请手动配置 $VIMRC_PATH。"
fi


log_info "Vim 配置完成."