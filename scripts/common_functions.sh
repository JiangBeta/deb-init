#!/bin/bash

# 通用函数库

# 设置日志文件路径
BASE_DIR="/tmp/deb-init"
LOG_FILE="$BASE_DIR/deb-init.log"

# 创建必要的目录
mkdir -p "$BASE_DIR"

# 全局SUDO命令和用户类型标志
SUDO_CMD=""
IS_ROOT=false

# --- 日志函数 ---
# 统一的日志格式化函数
format_log() {
    local level=$1
    local msg=$2
    local color=$3
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # 输出到终端（带颜色）
    printf "[\033[${color}m${level}\033[0m] %s\n" "$msg" >&3
    # 输出到日志文件（不带颜色，带时间戳）
    printf "[%s] %s %s\n" "$timestamp" "$level" "$msg" >> "$LOG_FILE"
}

log_info() {
    format_log "INFO" "$1" "32"
}

log_warn() {
    format_log "WARN" "$1" "33"
}

log_error() {
    format_log "ERROR" "$1" "31"
}

# 直接写入日志文件的函数（不输出到终端）
log_to_file() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] %s %s\n" "$timestamp" "$1" "$2" >> "$LOG_FILE"
}
# --- END 日志函数 ---


# --- Sudo 和用户检查 ---
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT=true
    log_info "脚本以 root 用户运行."
else
    IS_ROOT=false
    log_info "脚本以非 root 用户 ($(whoami)) 运行. 将检查并使用 sudo."
    if ! command -v sudo >/dev/null 2>&1; then
        log_error "sudo 命令未找到!"
        log_error "对于非 root 用户，sudo 是必需的以执行特权操作。"
        log_error "请先手动安装 sudo (例如: 以 root 身份运行 'apt-get update && apt-get install sudo')，"
        log_error "并将用户 $(whoami) 添加到 sudo 组 (例如: 'usermod -aG sudo $(whoami)'), 然后重新登录。"
        log_error "或者，请直接以 root 用户运行此脚本。"
        exit 1
    else
        SUDO_CMD="sudo"
        # 验证 sudo 权限
        # 1. 尝试非交互式验证 (适用于 NOPASSWD 或密码已缓存)
        if $SUDO_CMD -n -v >/dev/null 2>&1; then
            log_info "sudo 命令可用且权限已通过非交互式验证."
        else
            # 2. 如果非交互式失败，尝试交互式验证 (允许用户输入一次密码)
            log_warn "非交互式 sudo 验证失败. 尝试交互式验证..."
            log_warn "如果需要，系统可能会提示您输入用户 $(whoami) 的 sudo 密码."
            if $SUDO_CMD -v >/dev/null 2>&1; then
                log_info "sudo 命令可用且权限已通过交互式验证 (密码可能已输入)."
            else
                log_error "用户 $(whoami) 没有有效的 sudo 权限，或者 sudo 密码输入失败/未提供。"
                log_error "请确保用户 $(whoami) 在 sudoers 文件中并且可以成功执行 sudo 命令。"
                log_error "对于完全自动化的脚本，建议配置用户 $(whoami) 无需密码即可执行 sudo。"
                exit 1
            fi
        fi
    fi
fi
# --- END Sudo 和用户检查 ---


# --- 命令执行函数 ---
# 执行不需要sudo的命令
execute_command() {
    local cmd_desc="$1"
    shift
    log_info "正在执行: $cmd_desc"
    if "$@"; then
        log_info "$cmd_desc 完成."
    else
        log_error "$cmd_desc 失败. 脚本将终止."
        exit 1
    fi
}

# 执行可能需要sudo的命令 (根据IS_ROOT自动判断)
execute_command_sudo() {
    local cmd_desc="$1"
    shift
    if $IS_ROOT; then
        log_info "正在执行 (root): $cmd_desc"
        if "$@"; then # 直接执行命令
            log_info "$cmd_desc 完成."
        else
            log_error "$cmd_desc 失败. 脚本将终止."
            exit 1
        fi
    else
        # IS_ROOT is false, so SUDO_CMD must be "sudo" (checked above)
        log_info "正在执行 (sudo): $cmd_desc"
        if $SUDO_CMD "$@"; then
            log_info "$cmd_desc 完成."
        else
            log_error "$cmd_desc 失败. 脚本将终止."
            exit 1
        fi
    fi
}
# --- END 命令执行函数 ---


# --- 辅助函数 ---
# 检查命令是否已安装
check_command_installed() {
    command -v "$1" >/dev/null 2>&1
}

# 确保包已安装
ensure_packages() {
    local packages_to_install=()
    local pkg_name
    for pkg_name in "$@"; do
        # 使用 dpkg-query 检查包的精确安装状态
        if dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "install ok installed"; then
            log_info "软件包 '$pkg_name' 已安装."
        else
            # log_info "软件包 '$pkg_name' 未安装或状态未知." # 避免对每个未安装的包都输出这个
            packages_to_install+=("$pkg_name")
        fi
    done

    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log_info "准备安装以下缺失的软件包: ${packages_to_install[*]}"
        execute_command_sudo "更新apt缓存" apt-get update -qq
        execute_command_sudo "安装软件包 ${packages_to_install[*]}" apt-get install -y "${packages_to_install[@]}"
    else
        log_info "所有请求的软件包均已安装." # 只有当没有包需要安装时才输出这个
    fi
}

# 检查文件是否存在且包含特定内容
check_file_contains() {
    local file_path="$1"
    local search_string="$2"

    if $IS_ROOT; then
        if [ -f "$file_path" ] && grep -qF "$search_string" "$file_path"; then
            return 0 # 存在且包含
        else
            return 1 # 不存在或不包含
        fi
    else
        # 非 root 用户，需要 sudo
        if $SUDO_CMD test -f "$file_path" && $SUDO_CMD grep -qF "$search_string" "$file_path"; then
            return 0
        else
            return 1
        fi
    fi
}
# --- END 辅助函数 ---