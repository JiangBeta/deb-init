#!/bin/bash

# 主交互脚本
# set -e # 命令失败时立即退出，子脚本会处理各自的错误

# 确保在远程执行时也能正常工作
export TERM=xterm-256color

echo "DEBUG: 脚本开始执行." >> /tmp/debug_main.log

# 设置基础目录
BASE_DIR="/tmp/deb-init"
SCRIPTS_SUBDIR="$BASE_DIR/scripts"
LOG_FILE="$BASE_DIR/deb-init.log"
GITHUB_RAW_URL="https://raw.githubusercontent.com/JiangBeta/deb-init/refs/heads/main/scripts"

echo "DEBUG: BASE_DIR=$BASE_DIR" >> /tmp/debug_main.log
echo "DEBUG: SCRIPTS_SUBDIR=$SCRIPTS_SUBDIR" >> /tmp/debug_main.log

# 创建必要的目录
mkdir -p "$SCRIPTS_SUBDIR"
echo "DEBUG: 目录 $SCRIPTS_SUBDIR 创建完成." >> /tmp/debug_main.log

# 初始化日志文件
: > "$LOG_FILE"
echo "DEBUG: 日志文件 $LOG_FILE 初始化完成." >> /tmp/debug_main.log

# 保存原始的标准输出和错误输出
exec 3>&1 4>&2
echo "DEBUG: 标准输出和错误输出已保存." >> /tmp/debug_main.log

# 下载并执行脚本
download_and_run_script() {
    local script_name=$1
    local script_path="$SCRIPTS_SUBDIR/$script_name"
    local timestamp
    
    # 如果脚本不存在，从GitHub下载
    if [ ! -f "$script_path" ]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        printf "[%s] 正在从GitHub下载脚本: %s\n" "$timestamp" "$script_name" >> "$LOG_FILE"
        log_info "正在从GitHub下载脚本: $script_name"
        if ! wget -q "$GITHUB_RAW_URL/$script_name" -O "$script_path"; then
            log_error "下载脚本失败: $script_name"
            return 1
        fi
        chmod +x "$script_path"
    fi
    
    # 执行脚本
    log_info "开始执行脚本: $script_name"
    
    "$script_path"
    local ret=$?
    
    if [ $ret -eq 0 ]; then
        log_success "脚本 $script_name 执行完成"
    else
        log_error "脚本 $script_name 执行失败，返回值: $ret"
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
echo "DEBUG: 检查 common_functions.sh." >> /tmp/debug_main.log
if [ ! -f "$SCRIPTS_SUBDIR/common_functions.sh" ]; then
    echo "DEBUG: common_functions.sh 不存在，开始下载." >> /tmp/debug_main.log
    wget -q "$GITHUB_RAW_URL/common_functions.sh" -O "$SCRIPTS_SUBDIR/common_functions.sh"
    echo "DEBUG: common_functions.sh 下载完成." >> /tmp/debug_main.log
fi

# shellcheck source=./scripts/common_functions.sh
echo "DEBUG: 正在加载 common_functions.sh." >> /tmp/debug_main.log
source "$SCRIPTS_SUBDIR/common_functions.sh" # 加载通用函数，特别是日志和SUDO_CMD
echo "DEBUG: common_functions.sh 加载完成." >> /tmp/debug_main.log

# 运行环境准备脚本
echo "DEBUG: 正在运行 00_prepare_env.sh." >> /tmp/debug_main.log
download_and_run_script "00_prepare_env.sh" || exit 1
echo "DEBUG: 00_prepare_env.sh 执行完成." >> /tmp/debug_main.log


show_menu() {
    # 确保菜单内容直接输出到终端，不写入日志
    exec 1>&3 2>&4
    print_title "系统初始化与环境部署脚本"
    print_color "36" "请选择要执行的任务:" # 青色
    echo ""
    print_color "35" "--- 系统初始化 ---" # 紫色
    print_color "37" "  1. 执行所有系统初始化步骤 (时区, locale, 源, 基础软件)"
    print_color "37" "  2. 配置 SSH 服务"
    print_color "37" "  3. 配置 Vim"
    print_color "37" "  4. 配置 Zsh 和 Oh My Zsh"
    print_color "37" "  5. 执行以上所有 (1-4)"
    echo ""
    print_color "35" "--- Docker 服务配置 ---" # 紫色
    print_color "37" "  11. 安装和基础配置 Docker (引擎, Compose, 镜像, 日志)"
    print_color "37" "  12. 迁移 Docker 数据目录 (可选)"
    print_color "37" "  13. 执行以上所有 Docker 相关 (11-12)"
    echo ""
    print_color "35" "--- 完整流程 ---" # 紫色
    print_color "37" "  20. 执行所有系统初始化和 Docker 完整配置 (5 + 13)"
    echo ""
    print_color "33" "  q. 退出脚本" # 黄色
    print_separator "=" 50
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
        log_error "上一个操作执行失败. 请检查日志."
    else
        log_success "选择的操作执行完毕."
    fi
    echo ""
    read -n 1 -s -r -p "$(print_color "36" "按任意键返回主菜单...")" # 青色
}

# 主循环
echo "DEBUG: 进入主循环." >> /tmp/debug_main.log
while true; do
    exec 1>&3 2>&4  # 确保菜单输出到终端
    $SUDO_CMD clear
    show_menu
    read -r -p "$(print_color "36" "请输入您的选择: ")" user_choice # 青色
    execute_selection "$user_choice"
done