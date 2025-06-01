#!/bin/bash

# 设置日志文件路径
BASE_DIR="/tmp/deb-init"
LOG_FILE="$BASE_DIR/deb-init.log"

SCRIPT_DIR_PREPARE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_PREPARE/common_functions.sh"

# 确保日志输出到文件
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_info "阶段 0: 准备环境..."

# 检查 Sudo (已在 common_functions.sh 中处理，这里可以添加其他通用准备)

# 确保 wget 或 curl 至少有一个可用，优先 wget
if ! check_command_installed wget && ! check_command_installed curl; then
    log_warn "wget 和 curl 均未安装. 尝试安装 wget..."
    execute_command_sudo "安装 wget" apt-get update -qq
    execute_command_sudo "安装 wget" apt-get install -y wget
    if ! check_command_installed wget; then
        log_error "安装 wget 失败. 请手动安装 wget 后重试."
        exec 1>&3 2>&4  # 恢复标准输出
        exit 1
    fi
elif ! check_command_installed wget && check_command_installed curl; then
    log_warn "检测到 curl 可用但 wget 未安装，建议安装 wget..."
    execute_command_sudo "安装 wget" apt-get update -qq
    execute_command_sudo "安装 wget" apt-get install -y wget
fi

log_info "环境准备完成."

# 恢复标准输出
exec 1>&3 2>&4