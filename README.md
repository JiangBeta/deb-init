# 系统初始化与环境部署脚本

本项目提供一系列 Shell 脚本，用于快速初始化和部署 Debian、Ubuntu 及基于这些系统的 Armbian Server，使其符合个人使用习惯。

## 功能模块

### 1. 系统初始化
- **设置时区与时间**:
    - 时区: `Asia/Shanghai`
    - NTP 服务器: `ntp1.aliyun.com`
- **设置语言环境 (locales)**:
    - 添加 `en_US.UTF-8` 和 `zh_CN.UTF-8`
    - 默认 `en_US.UTF-8`
- **更换国内软件源**:
    - 使用 `https://linuxmirrors.cn/main.sh` 脚本自动选择最优源。
    - 系统更新与升级。
- **安装基础软件包**:
    - `sudo`, `vim`, `jq`, `tmux`, `curl`, `git`, `zsh`, `locales`, `gnupg2`, `lsb-release`, `apt-transport-https`, `ca-certificates`, `iproute2-doc`, `gawk`, `dnsutils`, `htop`, `nfs-common`, `pciutils`, `btrfs-progs`, `fonts-wqy-zenhei`

### 2. SSH 服务配置
- 确保 `openssh-server` 已安装。
- 允许 root 用户通过密码登录 (可按需调整)。
- 关闭 `pam_systemd.so` 会话注册，可能加快 SSH 登录速度（某些情况下）。
- 重启 SSH 服务。

### 3. Vim 配置
- 确保 `vim` 已安装。
- 从 `wklken/vim-for-server` 拉取 `.vimrc` 配置文件。

### 4. Zsh & Oh My Zsh 配置
- 确保 `zsh` 已安装。
- 安装 `Oh My Zsh` (如果未安装)。
- 安装 Zsh 插件:
    - `evalcache`
    - `zsh-syntax-highlighting`
    - `zsh-autosuggestions` (推测原 `zsh-syntax-highlighting` 重复，改为此常用插件)
    - `autojump` (包含其 Python 安装步骤)
- 更新 `.zshrc` 配置文件从指定 Gist。
- **注意**: `autojump` 插件安装后，可能需要新开一个 Zsh 终端才能正常工作。脚本会尝试设置 Zsh 为默认 shell。

### 5. Docker 服务配置
- **安装 Docker**:
    - 使用 `https://linuxmirrors.cn/docker.sh` 脚本安装最新版 Docker Engine。
- **安装 Docker Compose**:
    - 自动从 GitHub 获取最新稳定版 Docker Compose v2.x.x (独立二进制文件)。
    - 设置可执行权限。
- **配置 Docker 国内镜像源**:
    - 添加多个常用国内镜像地址到 `/etc/docker/daemon.json`。
- **设置 Docker 日志**:
    - 驱动: `json-file`
    - 最大大小: `10m`
    - 最大文件数: `3`
- **迁移 Docker 数据目录 (可选)**:
    - 交互式选项，允许用户指定新的 Docker 数据存储路径。
    - 自动备份并迁移数据。

## 使用方法

1.  **下载脚本**:
    ```bash
    git clone <your_repository_url> System_Initialization
    cd System_Initialization
    ```
2.  **授予执行权限**:
    ```bash
    chmod +x main.sh scripts/*.sh
    ```

3.  **运行主脚本**:
    ```bash
    ./main.sh
    ```
    脚本将显示一个菜单，您可以根据需要选择执行相应的模块。

## 注意事项
-   **执行权限**: 脚本会自动检测是否以 root 用户运行。如果不是 root 用户，关键命令会尝试使用 `sudo` 执行。请确保当前用户有 `sudo` 权限。
-   **网络连接**: 大部分步骤需要正常的网络连接以下载软件包和配置文件。
-   **幂等性**: 脚本设计时考虑了幂等性，即多次运行同一个脚本或模块，系统状态应保持一致，不会产生副作用（例如，重复安装软件或添加重复配置）。
-   **错误处理**: 脚本在关键命令执行失败时会输出错误信息并退出，以防止进一步的问题。
-   **Oh My Zsh 安装**: Oh My Zsh 安装脚本默认会尝试将 Zsh 设置为用户的默认 shell。如果脚本通过 `sudo` 为 root 用户执行这些操作，则会更改 root 用户的 shell。
-   **自定义**: 您可以根据个人需求修改 `scripts/` 目录下的各个子脚本。

## 扩展性
-   **添加新功能**:
    1.  在 `scripts/` 目录下创建一个新的 `NN_descriptive_name.sh` 脚本。
    2.  在新脚本中实现您的功能，遵循与其他脚本类似的错误处理和日志风格。
    3.  修改 `main.sh` 脚本，在菜单和 `case` 语句中添加新选项以调用您的新脚本。
-   **修改现有功能**:
    直接编辑 `scripts/` 目录下对应的脚本文件。建议先理解脚本的现有逻辑。

## Python Code 服务配置
此部分功能计划在未来添加。
