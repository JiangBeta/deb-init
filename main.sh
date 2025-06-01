#!/bin/bash

# 主交互脚本
# set -e # 命令失败时立即退出，子脚本会处理各自的错误

# 确保在远程执行时也能正常工作
export TERM=xterm-256color

# 设置基础目录
BASE_DIR="/tmp/deb-init"
SCRIPTS_SUBDIR="$BASE_DIR/scripts"
LOG_FILE="$BASE_DIR/deb-init.log"
GITHUB_RAW_URL="https://raw.githubusercontent.com/JiangBeta/deb-init/refs/heads/main/scripts"

# 创建必要的目录
mkdir -p "$SCRIPTS_SUBDIR"

# 初始化日志文件
: > "$LOG_FILE"

# 保存原始的标准输出和错误输出
exec 3>&1 4>&2

# 下载并执行脚本
download_and_run_script() {
    local script_name=$1
    local script_path="$SCRIPTS_SUBDIR/$script_name"
    local timestamp
    
    # 如果脚本不存在，从GitHub下载
    if [ ! -f "$script_path" ]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        printf "[%s] 正在从GitHub下载脚本: %s\n" "$timestamp" "$script_name" >> "$LOG_FILE"
        echo -e "\033[32m[INFO]\033[0m 正在从GitHub下载脚本: $script_name" >&3
        if ! wget -q "$GITHUB_RAW_URL/$script_name" -O "$script_path"; then
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            printf "[%s] 下载脚本失败: %s\n" "$timestamp" "$script_name" >> "$LOG_FILE"
            echo -e "\033[31m[ERROR]\033[0m 下载脚本失败: $script_name" >&3
            return 1
        fi
        chmod +x "$script_path"
    fi
    
    # 执行脚本
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] 开始执行脚本: %s\n" "$timestamp" "$script_name" >> "$LOG_FILE"
    echo -e "\033[32m[INFO]\033[0m 开始执行脚本: $script_name" >&3
    
    "$script_path"
    local ret=$?
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] 脚本 %s 执行完成，返回值: %d\n" "$timestamp" "$script_name" "$ret" >> "$LOG_FILE"
    if [ $ret -eq 0 ]; then
        echo -e "\033[32m[INFO]\033[0m 脚本 $script_name 执行完成" >&3
    else
        echo -e "\033[31m[ERROR]\033[0m 脚本 $script_name 执行失败，返回值: $ret" >&3
    fi
    
    return $ret
}

# 清理函数
cleanup() {
    log_info "开始清理临时文件..."
    exec 1>&3 2>&4  # 恢复标准输出和错误输出
    if [ "$1" != "keep" ]; then
        log_info "清理临时目录: $SCRIPTS_SUBDIR"
        rm -rf "$SCRIPTS_SUBDIR"
        log_info "完整日志已保存至: $LOG_FILE"
    fi
}

# 注册清理函数
trap 'cleanup' EXIT
trap 'cleanup; exit 1' INT TERM

# 首先下载通用函数脚本
if [ ! -f "$SCRIPTS_SUBDIR/common_functions.sh" ]; then
    wget -q "$GITHUB_RAW_URL/common_functions.sh" -O "$SCRIPTS_SUBDIR/common_functions.sh"
fi

# shellcheck source=./scripts/common_functions.sh
source "$SCRIPTS_SUBDIR/common_functions.sh" # 加载通用函数，特别是日志和SUDO_CMD

# 运行环境准备脚本
download_and_run_script "00_prepare_env.sh" || exit 1


show_menu() {
    # 确保菜单内容直接输出到终端，不写入日志
    exec 1>&3 2>&4
    echo "===================================================="
    echo "          系统初始化与环境部署脚本"
    echo "===================================================="
    echo "请选择要执行的任务:"
    echo ""
    echo "--- 系统初始化 ---"
    echo "  1. 执行所有系统初始化步骤 (时区, locale, 源, 基础软件)"
    echo "  2. 配置 SSH 服务"
    echo "  3. 配置 Vim"
    echo "  4. 配置 Zsh 和 Oh My Zsh"
    echo "  5. 执行以上所有 (1-4)"
    echo ""
    echo "--- Docker 服务配置 ---"
    echo "  11. 安装和基础配置 Docker (引擎, Compose, 镜像, 日志)"
    echo "  12. 迁移 Docker 数据目录 (可选)"
    echo "  13. 执行以上所有 Docker 相关 (11-12)"
    echo ""
    echo "--- 完整流程 ---"
    echo "  20. 执行所有系统初始化和 Docker 完整配置 (5 + 13)"
    echo ""
    echo "  q. 退出脚本"
    echo "===================================================="
}

execute_selection() {
    local choice=$1
    case $choice in
        1)
            download_and_run_script "01_system_init.sh"
            ;;
        2)
            download_and_run_script "02_ssh_setup.sh"
            ;;
        3)
            download_and_run_script "03_vim_setup.sh"
            ;;
        4)
            download_and_run_script "04_zsh_setup.sh"
            ;;
        5)
            log_info "执行所有系统初始化步骤 (1-4)..."
            download_and_run_script "01_system_init.sh" && \
            download_and_run_script "02_ssh_setup.sh" && \
            download_and_run_script "03_vim_setup.sh" && \
            download_and_run_script "04_zsh_setup.sh"
            ;;
        11)
            download_and_run_script "11_docker_install_config.sh"
            ;;
        12)
            download_and_run_script "12_docker_data_migrate.sh"
            ;;
        13)
            log_info "执行所有 Docker 相关配置 (11-12)..."
            download_and_run_script "11_docker_install_config.sh" && \
            download_and_run_script "12_docker_data_migrate.sh"
            ;;
        20)
            log_info "执行完整的系统初始化和 Docker 配置..."
            download_and_run_script "01_system_init.sh" && \
            download_and_run_script "02_ssh_setup.sh" && \
            download_and_run_script "03_vim_setup.sh" && \
            download_and_run_script "04_zsh_setup.sh" && \
            download_and_run_script "11_docker_install_config.sh" && \
            download_and_run_script "12_docker_data_migrate.sh"
            ;;
        q|Q)
            log_info "退出脚本."
            exit 0
            ;;
        *)
            log_warn "无效的选项: $choice"
            ;;
    esac
    
    # 检查执行结果并输出到终端
    exec 1>&3 2>&4
    if [ $? -ne 0 ]; then
        echo -e "\033[31m[ERROR]\033[0m 上一个操作执行失败. 请检查日志."
    else
        echo -e "\033[32m[INFO]\033[0m 选择的操作执行完毕."
    fi
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..."
}

# 主循环
while true; do
    exec 1>&3 2>&4  # 确保菜单输出到终端
    $SUDO_CMD clear
    show_menu
    read -r -p "请输入您的选择: " user_choice
    execute_selection "$user_choice"
done