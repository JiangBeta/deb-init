#!/bin/bash

SCRIPT_DIR_PREPARE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_PREPARE/common_functions.sh"

log_info "阶段 0: 准备环境..."

# 检查 Sudo (已在 common_functions.sh 中处理，这里可以添加其他通用准备)

# 确保 wget 或 curl 至少有一个可用，优先 curl
# 许多初始系统可能只有 wget
if ! check_command_installed curl && ! check_command_installed wget; then
    log_warn "curl 和 wget 均未安装. 尝试安装 curl..."
    execute_command_sudo "安装 curl" apt-get update -qq
    execute_command_sudo "安装 curl" apt-get install -y curl
    if ! check_command_installed curl; then
        log_error "安装 curl 失败. 请手动安装 curl 或 wget 后重试."
        exit 1
    fi
elif ! check_command_installed curl && check_command_installed wget; then
    log_warn "curl 未安装, 但 wget 可用. 部分脚本可能依赖 curl，尝试安装 curl..."
    execute_command_sudo "安装 curl" apt-get update -qq
    execute_command_sudo "安装 curl" apt-get install -y curl
fi

log_info "环境准备完成."