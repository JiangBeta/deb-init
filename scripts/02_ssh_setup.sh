#!/bin/bash

# 设置日志文件路径
BASE_DIR="/tmp/deb-init"
LOG_FILE="$BASE_DIR/deb-init.log"

SCRIPT_DIR_SSH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_SSH/common_functions.sh"

# 确保日志输出到文件
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_info "阶段 1.1.5: SSH 服务配置开始..."

# 确认安装 openssh-server
ensure_packages openssh-server

SSH_CONFIG_FILE="/etc/ssh/sshd_config"

# 设置root可登陆
log_info "设置 root 用户可 SSH 登录 (PermitRootLogin yes)..."
# 检查 PermitRootLogin 是否已存在
if grep -qE "^#?\s*PermitRootLogin" "$SSH_CONFIG_FILE"; then
    # 如果存在，则修改为 yes，并取消注释
    execute_command_sudo "修改 PermitRootLogin" sed -i -E 's/^#?\s*(PermitRootLogin\s+).*/\1yes/' "$SSH_CONFIG_FILE"
else
    # 如果不存在，则追加
    execute_command_sudo "添加 PermitRootLogin" sh -c "echo 'PermitRootLogin yes' >> $SSH_CONFIG_FILE"
fi

# 关闭 pam 注册用户会话
log_info "尝试关闭 pam_systemd.so 会话注册以加快 SSH 登录..."
PAM_COMMON_SESSION_FILE="/etc/pam.d/common-session"
PAM_SYSTEMD_LINE_PATTERN="^[[:space:]]*session[[:space:]]\+optional[[:space:]]\+pam_systemd\.so"

if [ -f "$PAM_COMMON_SESSION_FILE" ]; then
    if grep -qE "$PAM_SYSTEMD_LINE_PATTERN" "$PAM_COMMON_SESSION_FILE"; then
        # 检查是否已被注释
        if grep -qE "^#${PAM_SYSTEMD_LINE_PATTERN}" "$PAM_COMMON_SESSION_FILE"; then
            log_info "pam_systemd.so 在 $PAM_COMMON_SESSION_FILE 中已注释."
        else
            execute_command_sudo "注释 pam_systemd.so" sed -i "s|^\(${PAM_SYSTEMD_LINE_PATTERN}\)|#\1|" "$PAM_COMMON_SESSION_FILE"
            log_info "已注释 pam_systemd.so 以尝试加快SSH登录速度."
        fi
    else
        log_info "未在 $PAM_COMMON_SESSION_FILE 中找到 pam_systemd.so 相关行."
    fi
else
    log_warn "$PAM_COMMON_SESSION_FILE 文件未找到, 跳过 pam_systemd.so 配置."
fi

# 重启 ssh 服务
log_info "重启 SSH 服务..."
if systemctl list-units --type=service | grep -q "ssh.service"; then
    execute_command_sudo "重启 ssh.service" systemctl restart ssh.service
elif systemctl list-units --type=service | grep -q "sshd.service"; then
    execute_command_sudo "重启 sshd.service" systemctl restart sshd.service
else
    log_warn "未能确定SSH服务名称 (ssh.service 或 sshd.service). 请手动重启SSH服务."
fi

log_info "SSH 服务配置完成."

# 恢复标准输出
exec 1>&3 2>&4