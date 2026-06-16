#!/usr/bin/env bash
# shellcheck disable=SC2162
set -euo pipefail

# Claude Code 一键安装脚本（macOS / Linux / WSL）
# 支持 curl | bash 管道执行

RED='\033[0;31m';  GREEN='\033[0;32m';  YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "  ${CYAN}INFO${NC}  %s\n" "$*"; }
ok()    { printf "  ${GREEN}OK${NC}    %s\n" "$*"; }
warn()  { printf "  ${YELLOW}WARN${NC} %s\n" "$*"; }
err()   { printf "  ${RED}ERROR${NC} %s\n" "$*"; }
step()  { printf "\n${BOLD}${MAGENTA}>> %s${NC}\n" "$*"; }

# 管道执行的 read 需要用 /dev/tty 获取用户输入
read_input() {
  local prompt="$1" default="$2"
  local result
  if [ -t 0 ]; then
    read -r -p "$prompt" result
  else
    printf "%s" "$prompt" > /dev/tty
    read -r result < /dev/tty
  fi
  echo "${result:-$default}"
}

detect_platform() {
  case "$(uname -s)" in
    Darwin*) echo 'macos' ;;
    Linux*)
      grep -qi microsoft /proc/version 2>/dev/null && echo 'wsl' || echo 'linux' ;;
    *) echo 'unknown' ;;
  esac
}

check_prereqs() {
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    err '需要 curl 或 wget，请先安装其中之一'
    exit 1
  fi
  # 管道执行时需要 /dev/tty 做交互
  if ! [ -t 0 ] && ! [ -e /dev/tty ]; then
    err '终端不可用，无法进行交互式安装。请直接下载脚本后本地运行。'
    exit 1
  fi
}

install_native() {
  step '1/4：下载并执行 Claude Code 安装脚本...'
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash
  else
    wget -qO- https://claude.ai/install.sh | bash
  fi
  ok '安装脚本执行完成'
}

verify_install() {
  step '3/4：验证安装...'
  if command -v claude >/dev/null 2>&1; then
    ok "Claude Code $(claude --version) 安装成功"
  else
    warn 'claude 命令暂未在 PATH 中，请重启终端后重试'
  fi
}

setup_auth() {
  printf "
  选择认证方式：

    [1] 浏览器 OAuth（推荐）— 打开浏览器登录 Claude 账号
    [2] API Key            — 使用 console.anthropic.com 的 API 密钥
    [S] 跳过                — 稍后手动配置

"
  choice=$(read_input '  请输入 [1]: ' '1')

  case "$choice" in
    1)
      info '正在启动浏览器认证...'
      claude login
      ;;
    2)
      api_key=$(read_input '  粘贴你的 Anthropic API 密钥: ' '')
      if [ -n "$api_key" ]; then
        mkdir -p "$HOME/.claude"
        if grep -q '^ANTHROPIC_API_KEY=' "$HOME/.claude/.env" 2>/dev/null; then
          sed -i.bak "s/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=$api_key/" "$HOME/.claude/.env"
        else
          printf 'ANTHROPIC_API_KEY=%s\n' "$api_key" >> "$HOME/.claude/.env"
        fi
        export ANTHROPIC_API_KEY="$api_key"
        ok 'API 密钥已保存'
      fi
      ;;
    *)
      info '已跳过。稍后运行 claude login 完成认证'
      ;;
  esac
}

setup_model() {
  printf "
  选择 Claude Code 使用的模型：

    [1] Claude Sonnet 4（默认）— 速度与质量的平衡，日常开发推荐
    [2] Claude Opus 4          — 最强推理能力，适合复杂任务
    [3] Claude Sonnet 3.5      — 成熟稳定版
    [4] 自定义模型              — 手动输入模型名称

"
  choice=$(read_input '  请输入 [1]: ' '1')

  case "$choice" in
    1) model='claude-sonnet-4-20250514' ;;
    2) model='claude-opus-4-20250514' ;;
    3) model='claude-sonnet-3-5-20241022' ;;
    4) model=$(read_input '  输入模型名称（如 claude-sonnet-4-20250514）: ' '') ;;
    *) model='claude-sonnet-4-20250514' ;;
  esac
  [ -z "$model" ] && model='claude-sonnet-4-20250514'

  mkdir -p "$HOME/.claude"
  if grep -q '^ANTHROPIC_MODEL=' "$HOME/.claude/.env" 2>/dev/null; then
    sed -i.bak "s/^ANTHROPIC_MODEL=.*/ANTHROPIC_MODEL=$model/" "$HOME/.claude/.env"
  else
    printf 'ANTHROPIC_MODEL=%s\n' "$model" >> "$HOME/.claude/.env"
  fi
  export ANTHROPIC_MODEL="$model"
  ok "模型已配置为：$model"
}

# ===== 主流程 =====
clear
printf "${BOLD}${MAGENTA}
  ╔══════════════════════════════════════════╗
  ║         Claude Code 一键安装脚本         ║
  ╚══════════════════════════════════════════╝
${NC}\n"

info '正在检测系统环境...'
platform=$(detect_platform)
ok "系统平台：$platform"
info '需要 Claude Pro/Max/Team/Enterprise 订阅或 API 密钥'
echo ''

check_prereqs

# 模型配置
do_model=$(read_input '  是否配置 Claude Code 使用的模型？[y/N]: ' 'N')
if [ "$do_model" = 'y' ] || [ "$do_model" = 'Y' ]; then
  setup_model
fi

install_native

step '2/4：等待安装完成...'
sleep 2

verify_install

# 认证
do_auth=$(read_input '  是否进行账号认证？[Y/n]: ' 'Y')
if [ "$do_auth" = 'y' ] || [ "$do_auth" = 'Y' ] || [ "$do_auth" = '' ]; then
  setup_auth
fi

printf "${BOLD}${GREEN}
  ┌──────────────────────────────────────┐
  │        ✓ 安装完成！                  │
  └──────────────────────────────────────┘
${NC}
  快速开始：
    cd your-project
    claude

  常用命令：
    claude --help     查看帮助
    claude doctor     运行诊断
    claude login      重新认证

  更新：
    原生安装会自动后台更新
    或重新运行本脚本

${NC}"
