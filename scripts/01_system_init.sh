#!/bin/bash

# 设置日志文件路径
BASE_DIR="/tmp/deb-init"
LOG_FILE="$BASE_DIR/deb-init.log"

SCRIPT_DIR_INIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_INIT/common_functions.sh"

# 确保日志输出到文件
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_info "阶段 1.1: 系统初始化开始..."

# 1.1.1 设置时区时间
log_info "1.1.1 设置时区为 Asia/Shanghai..."
execute_command_sudo "设置时区" timedatectl set-timezone Asia/Shanghai

log_info "配置NTP服务使用 ntp1.aliyun.com..."
NTP_CONF_FILE="/etc/systemd/timesyncd.conf"
if [ -f "$NTP_CONF_FILE" ]; then
    # 检查是否已配置NTP服务器
    if grep -qE "^#?NTP=" "$NTP_CONF_FILE"; then
        execute_command_sudo "修改NTP服务器" sed -i -E 's/^#?(NTP=).*/\1ntp1.aliyun.com/' "$NTP_CONF_FILE"
    else
        execute_command_sudo "添加NTP服务器" sh -c "echo 'NTP=ntp1.aliyun.com' >> $NTP_CONF_FILE"
    fi
    # 检查是否已配置FallbackNTP服务器，如果需要可以也设置
    if grep -qE "^#?FallbackNTP=" "$NTP_CONF_FILE"; then
         # 可以选择注释掉 FallbackNTP 或者也设置为阿里云的
        execute_command_sudo "注释默认FallbackNTP" sed -i -E 's/^(FallbackNTP=.*)/#\1/' "$NTP_CONF_FILE"
    fi
    execute_command_sudo "重启 systemd-timesyncd 服务" systemctl restart systemd-timesyncd
    execute_command_sudo "启用NTP同步" timedatectl set-ntp true
    log_info "NTP配置完成. 当前时间:"
    date
else
    log_warn "$NTP_CONF_FILE 未找到. 跳过NTP配置. 请检查您的系统是否使用 systemd-timesyncd."
fi

# 1.1.2 设置 locales
log_info "1.1.2 设置locales..."
ensure_packages locales
LOCALE_GEN_FILE="/etc/locale.gen"
EN_US_LOCALE="en_US.UTF-8 UTF-8"
ZH_CN_LOCALE="zh_CN.UTF-8 UTF-8"

# 检查并取消注释 en_US.UTF-8
if grep -q "^# *$EN_US_LOCALE" "$LOCALE_GEN_FILE"; then
    execute_command_sudo "启用 en_US.UTF-8 locale" sed -i "s/^# *$EN_US_LOCALE/$EN_US_LOCALE/" "$LOCALE_GEN_FILE"
elif ! grep -q "^ *$EN_US_LOCALE" "$LOCALE_GEN_FILE"; then
    execute_command_sudo "添加 en_US.UTF-8 locale" sh -c "echo '$EN_US_LOCALE' >> $LOCALE_GEN_FILE"
fi

# 检查并取消注释 zh_CN.UTF-8
if grep -q "^# *$ZH_CN_LOCALE" "$LOCALE_GEN_FILE"; then
    execute_command_sudo "启用 zh_CN.UTF-8 locale" sed -i "s/^# *$ZH_CN_LOCALE/$ZH_CN_LOCALE/" "$LOCALE_GEN_FILE"
elif ! grep -q "^ *$ZH_CN_LOCALE" "$LOCALE_GEN_FILE"; then
    execute_command_sudo "添加 zh_CN.UTF-8 locale" sh -c "echo '$ZH_CN_LOCALE' >> $LOCALE_GEN_FILE"
fi

execute_command_sudo "生成locales" locale-gen
execute_command_sudo "设置默认locale为 en_US.UTF-8" update-locale LANG=en_US.UTF-8
# 使当前会话也生效，可能需要重新登录或 source /etc/default/locale
export LANG=en_US.UTF-8

# 1.1.3 设置国内源
log_info "1.1.3 设置国内源..."
MIRRORS_SCRIPT_URL="https://linuxmirrors.cn/main.sh"
MIRRORS_SCRIPT_PATH="/tmp/main.sh"
if ! check_command_installed curl; then # 确保 curl 已安装 (00_prepare_env.sh会做)
    ensure_packages curl
fi

# 初始系统没有curl，使用wget
log_info "使用 wget 下载换源脚本..."
if $SUDO_CMD wget "$MIRRORS_SCRIPT_URL" -O "$MIRRORS_SCRIPT_PATH"; then
    log_info "换源脚本下载成功. 执行换源脚本..."
    # shellcheck disable=SC2086
    $SUDO_CMD bash "$MIRRORS_SCRIPT_PATH" # 脚本可能会有交互，按需调整
    # shellcheck disable=SC2086
    $SUDO_CMD rm "$MIRRORS_SCRIPT_PATH"
else
    log_error "下载换源脚本失败. 请检查网络或URL: $MIRRORS_SCRIPT_URL"
    # 不退出，允许继续，但后续更新可能失败
fi

log_info "更新系统软件包列表并升级系统..."
execute_command_sudo "更新软件包列表" apt-get update -qq
execute_command_sudo "升级已安装软件包" apt-get upgrade -y

# 1.1.4 安装基础软件
log_info "1.1.4 安装基础软件..."
# sudo 在 armbian 等系统初始可能没有，但 apt install sudo 会解决
# lsb-release 和 ca-certificates 通常用于添加第三方源，提前安装是好的
# apt-transport-https 也是
BASE_PACKAGES=(
    sudo vim jq tmux curl git zsh locales gnupg2 lsb-release apt-transport-https
    ca-certificates iproute2-doc gawk dnsutils htop nfs-common pciutils btrfs-progs
    fonts-wqy-zenhei
)
ensure_packages "${BASE_PACKAGES[@]}"

log_info "系统初始化阶段完成."

# 恢复标准输出
exec 1>&3 2>&4