#!/bin/bash

SCRIPT_DIR_ZSH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_ZSH/common_functions.sh"

log_info "阶段 1.1.7: Zsh 和 Oh My Zsh 配置开始..."

# 确认安装 zsh 和 git (git是oh-my-zsh和插件安装的依赖)
ensure_packages zsh git

# 为哪个用户安装 Zsh？ 通常是当前用户或 root
# 我们将假定为当前执行脚本的用户（如果是root，那就是root）
TARGET_USER_HOME="$HOME"
if [ "$(id -u)" -eq 0 ]; then
    TARGET_USER_HOME="/root"
fi
ZSHRC_PATH="$TARGET_USER_HOME/.zshrc"
OH_MY_ZSH_DIR="$TARGET_USER_HOME/.oh-my-zsh"

# 1. 安装 Oh My Zsh
log_info "检查 Oh My Zsh 安装情况..."
if [ ! -d "$OH_MY_ZSH_DIR" ]; then
    log_info "Oh My Zsh 未安装. 开始安装..."
    OHMYZSH_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    OHMYZSH_INSTALL_SCRIPT_PATH="/tmp/ohmyzsh_install.sh"

    # 下载安装脚本
    # wget or curl, curl should be available from 01_system_init.sh
    if ! curl -fsSL "$OHMYZSH_INSTALL_SCRIPT_URL" -o "$OHMYZSH_INSTALL_SCRIPT_PATH"; then
        log_error "下载 Oh My Zsh 安装脚本失败. URL: $OHMYZSH_INSTALL_SCRIPT_URL"
        exit 1
    fi

    # 执行安装脚本，不自动切换shell，不自动运行zsh
    # 通过管道传递 "Y" 来自动确认 (install.sh 似乎不再需要这个，但为了保险)
    # CHSH=no:不尝试改变默认shell, RUNZSH=no:安装后不立即运行zsh
    log_info "执行 Oh My Zsh 安装脚本 (CHSH=no, RUNZSH=no)..."
    # Oh My Zsh的安装脚本会处理目标用户的 $HOME
    # 如果以sudo执行，脚本内部逻辑可能需要调整以针对特定用户，但其默认行为是 $HOME
    # 如果当前用户是root, $HOME是/root. 如果是普通用户， $HOME是 /home/user
    # 执行 sh $OHMYZSH_INSTALL_SCRIPT_PATH 时，它会在当前用户的 $HOME 下操作
    # 如果我们是 root，那么 $HOME 就是 /root
    # 如果我们是普通用户 `suer` 执行 `sudo ./main.sh`，脚本里的 `$HOME` 指向 `/home/user`
    # 而 Oh My Zsh 安装脚本自身会使用 `whoami` 或类似方式确定用户，并在其家目录安装
    # 因此，我们不需要特殊处理 $HOME，除非 Oh My Zsh 脚本行为怪异
    
    # 为了让 Oh My Zsh 安装到正确用户的家目录（即使是通过 sudo 运行）
    # 我们可以用 `sh -c "..." USER_HOME=$TARGET_USER_HOME` 但 install.sh 本身应该能处理
    # 我们直接执行，它会使用当前用户的 $HOME
    # 如果是以 `sudo ./script.sh` 运行，则当前用户是root，HOME=/root
    # 如果是 `su user -c ./script.sh`，则当前用户是user，HOME=/home/user

    if sh "$OHMYZSH_INSTALL_SCRIPT_PATH" --unattended --keep-zshrc; then
    # --unattended 选项可以避免交互
    # --keep-zshrc 保留已有的 .zshrc (如果我们要下载自己的，这个可能有用，或者后续覆盖)
        log_info "Oh My Zsh 安装成功."
        # shellcheck disable=SC2086
        $SUDO_CMD rm "$OHMYZSH_INSTALL_SCRIPT_PATH"
    else
        log_error "Oh My Zsh 安装失败."
        # shellcheck disable=SC2086
        $SUDO_CMD rm "$OHMYZSH_INSTALL_SCRIPT_PATH"
        exit 1
    fi
else
    log_info "Oh My Zsh 已安装在 $OH_MY_ZSH_DIR."
fi

# 2. 定义ZSH_CUSTOM路径
# ZSH_CUSTOM 环境变量可能在当前非zsh脚本中未定义
ZSH_CUSTOM="${ZSH_CUSTOM:-$TARGET_USER_HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
# shellcheck disable=SC2086
$SUDO_CMD mkdir -p "$PLUGINS_DIR" # 确保插件目录存在，并处理权限

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

# zsh-autosuggestions (假设第二个 zsh-syntax-highlighting 是笔误)
AUTOSUGGESTIONS_DIR="$PLUGINS_DIR/zsh-autosuggestions"
if [ ! -d "$AUTOSUGGESTIONS_DIR" ]; then
    log_info "安装插件: zsh-autosuggestions..."
    execute_command "克隆 zsh-autosuggestions" git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGESTIONS_DIR"
else
    log_info "插件 zsh-autosuggestions 已存在."
fi

# autojump
AUTOJUMP_DIR="$PLUGINS_DIR/autojump"
if [ ! -d "$AUTOJUMP_DIR" ]; then
    log_info "安装插件: autojump..."
    execute_command "克隆 autojump" git clone https://github.com/wting/autojump.git "$AUTOJUMP_DIR"
    
    log_info "执行 autojump 安装脚本 (./install.py)..."
    PYTHON_CMD="python3" # 优先 python3
    if ! check_command_installed python3; then
        if check_command_installed python; then
            PYTHON_CMD="python"
        else
            log_warn "未找到 python3 或 python. autojump 可能安装失败或需要手动安装 python."
            # 尝试安装 python3
            ensure_packages python3
            if ! check_command_installed python3; then
                 log_error "安装 python3 失败. autojump 安装被跳过."
                 # 不退出，允许继续，但 autojump 可能不工作
            fi
        fi
    fi
    
    if [ -f "$AUTOJUMP_DIR/install.py" ]; then
        (cd "$AUTOJUMP_DIR" && execute_command "运行 autojump install.py" "$PYTHON_CMD" ./install.py)
        # install.py 可能会在家目录创建 .autojump 目录
    elif [ -f "$AUTOJUMP_DIR/bin/autojump.py" ]; then # 有些版本结构不同
        log_warn "autojump install.py 未找到, 但找到了 bin/autojump.py. 可能需要手动配置."
    else
        log_warn "autojump 安装脚本 (install.py) 未找到."
    fi
else
    log_info "插件 autojump 已存在."
    # 可以考虑检查 ./install.py 是否已运行过，但通常重复运行无害
    if [ -f "$AUTOJUMP_DIR/install.py" ]; then
        PYTHON_CMD=$(command -v python3 || command -v python || echo "python_not_found")
        if [ "$PYTHON_CMD" != "python_not_found" ]; then
            log_info "重新运行 autojump install.py 以确保其配置..."
            (cd "$AUTOJUMP_DIR" && $PYTHON_CMD ./install.py --no-update > /dev/null 2>&1) # 静默运行
        fi
    fi
fi

# 4. 更新 .zshrc
ZSHRC_GIST_URL="https://gist.github.com/JiangBeta/1ccc2a827ac30cf7bf4dfc3d8830db54/raw/cd8e80332c80df1a780aa48d0f64c7f17ca7c36c/.zshrc"
log_info "下载自定义 .zshrc 文件..."

# 备份现有的 .zshrc
if [ -f "$ZSHRC_PATH" ]; then
    # shellcheck disable=SC2086
    $SUDO_CMD cp "$ZSHRC_PATH" "${ZSHRC_PATH}.backup_$(date +%Y%m%d%H%M%S)"
    log_info "已备份 $ZSHRC_PATH 为 ${ZSHRC_PATH}.backup_..."
fi

# 下载新的 .zshrc
# 使用 curl 下载到 $ZSHRC_PATH, 需要确保 $TARGET_USER_HOME 的权限
# 如果是root执行，TARGET_USER_HOME 是 /root, curl 直接写
# 如果是普通用户 sudo 执行，TARGET_USER_HOME 是 /home/user, curl 也直接写
if curl -fsSL "$ZSHRC_GIST_URL" -o "$ZSHRC_PATH"; then
    log_info ".zshrc 文件已更新自 $ZSHRC_GIST_URL."
    # 确保下载的 .zshrc 文件的所有权是目标用户
    if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER_HOME" != "/root" ]; then # root 为其他用户操作
        TARGET_USER_NAME=$(basename "$TARGET_USER_HOME")
        # shellcheck disable=SC2086
        $SUDO_CMD chown "$TARGET_USER_NAME:$TARGET_USER_NAME" "$ZSHRC_PATH"
    elif [ "$(id -u)" -ne 0 ]; then # 普通用户 sudo 操作，文件应属于自己
        CURRENT_USER=$(whoami)
        # shellcheck disable=SC2086
        $SUDO_CMD chown "$CURRENT_USER:$CURRENT_USER" "$ZSHRC_PATH"
    fi
else
    log_error "下载 .zshrc 文件失败. URL: $ZSHRC_GIST_URL"
    log_warn "如果之前有备份，可以从备份恢复。"
fi

# 5. 设置Zsh为默认Shell (如果当前不是)
ZSH_PATH=$(which zsh)
if [ -n "$ZSH_PATH" ]; then
    CURRENT_SHELL=$(getent passwd "$(whoami)" | cut -d: -f7)
    if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
        log_info "尝试将 Zsh 设置为当前用户 ($(whoami)) 的默认 shell..."
        # chsh 可能需要交互输入密码，即使是 sudo
        # 对于root用户，这通常没有问题
        if $SUDO_CMD chsh -s "$ZSH_PATH" "$(whoami)"; then
            log_info "Zsh 已成功设置为默认 shell. 请重新登录或启动新的终端会话以使更改生效."
        else
            log_warn "设置 Zsh 为默认 shell 失败. 您可能需要手动执行: chsh -s $ZSH_PATH $(whoami)"
        fi
    else
        log_info "Zsh已经是当前用户的默认shell."
    fi
else
    log_warn "未找到 zsh 程序, 无法设置为默认 shell."
fi


log_info "Zsh 和 Oh My Zsh 配置完成."
log_warn "您可能需要重新登录或启动新的终端会话 (或运行 'source $ZSHRC_PATH') 以使所有 Zsh 更改生效."