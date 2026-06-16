<#
.SYNOPSIS
    Claude Code 一键安装脚本
.DESCRIPTION
    全中文交互，自动检测平台，支持模型配置。
    支持 Windows / macOS / Linux / WSL。
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 强制启用 TLS 1.2，解决 claude.ai 连接失败问题
if (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

$ESC = [char]27
function Color  { param($c,$t) "$ESC[$c" + 'm' + "$t$ESC[0m" }
function Info   { Write-Host ("  " + (Color 36 'INFO') + "  ") -NoNewline; Write-Host $args }
function Ok     { Write-Host ("  " + (Color 32 'OK') + "    ") -NoNewline; Write-Host $args }
function Warn   { Write-Host ("  " + (Color 33 'WARN') + " ") -NoNewline; Write-Host $args }
function Err    { Write-Host ("  " + (Color 31 'ERROR')) -NoNewline; Write-Host $args }
function Step   { Write-Host "`n$(Color '1;35' ">> $args")" }

function HasCmd { param($n); return [bool](Get-Command -Name $n -ErrorAction SilentlyContinue) }

function Get-Platform {
    if ($IsWindows -or [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        if (Test-Path '/proc/sys/fs/binfmt_misc/WSLInterop') { return 'wsl' }
        return 'windows'
    } elseif ($IsMacOS) { return 'macos' }
    elseif ($IsLinux) { return 'linux' }
    return 'unknown'
}

function Install-Native {
    $p = Get-Platform
    switch ($p) {
        'windows' {
            Step '1/4：下载 Claude Code 原生安装包...'
            $pkg = "$env:TEMP\claude-install.cmd"
            Invoke-WebRequest -Uri 'https://claude.ai/install.cmd' -OutFile $pkg -UseBasicParsing
            Ok '下载完成'
            Step '2/4：执行安装程序...'
            & cmd /c "`"$pkg`""
            Remove-Item $pkg -Force -ErrorAction SilentlyContinue
        }
        { $_ -in 'macos','linux','wsl' } {
            Step '1/4：下载并执行 Claude Code 安装脚本...'
            if (HasCmd 'curl') {
                bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
            } elseif (HasCmd 'wget') {
                bash -c 'wget -qO- https://claude.ai/install.sh | bash'
            } else {
                Err '未找到 curl 或 wget，请先安装其中之一'
                throw
            }
        }
        default { Err "不支持的系统：$p"; throw }
    }
}

function Install-Npm {
    Step '1/4：检查 Node.js 环境...'
    if (-not (HasCmd 'node')) {
        Err '未安装 Node.js，请先安装 Node.js 18+'
        Info '下载地址：https://nodejs.org/'
        throw
    }
    Ok "Node.js $(node -v) 已就绪"
    Step '2/4：通过 npm 安装 Claude Code...'
    npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -ne 0) { throw 'npm 安装失败' }
    Ok 'npm 安装完成'
}

function Install-Code {
    param([string]$Method = 'native')
    switch ($Method) {
        'native' { Install-Native }
        'npm'    { Install-Npm }
    }
    Step '3/4：验证安装...'
    Start-Sleep -Seconds 2
    if (HasCmd 'claude') {
        $ver = claude --version 2>&1
        Ok "Claude Code $ver 安装成功"
    } else {
        Warn 'claude 命令暂未出现在 PATH 中'
        Info '请关闭并重新打开终端，或手动刷新环境变量'
    }
}

function Setup-Auth {
    Write-Host @"

  选择认证方式：

    [1] 浏览器 OAuth（推荐）— 打开浏览器登录 Claude 账号
    [2] API Key            — 使用 console.anthropic.com 的 API 密钥
    [S] 跳过                — 稍后手动配置

"@
    $c = Read-Host '  请输入 [1]'
    if ($c -eq '') { $c = '1' }
    switch ($c) {
        '1' {
            Info '正在启动浏览器认证...'
            & claude login
        }
        '2' {
            $key = Read-Host -Prompt '  粘贴你的 Anthropic API 密钥'
            $dir = if ($IsWindows) { "$env:USERPROFILE\.claude" } else { "$HOME\.claude" }
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Set-Content -Path "$dir\.env" -Value "ANTHROPIC_API_KEY=$key"
            $env:ANTHROPIC_API_KEY = $key
            if ($IsWindows) { [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $key, 'User') }
            Ok 'API 密钥已保存'
        }
        default { Info '已跳过。稍后运行 claude login 完成认证' }
    }
}

function Setup-Model {
    Write-Host @"

  选择 Claude Code 使用的模型：

    [1] Claude Sonnet 4（默认）— 速度与质量的平衡，日常开发推荐
    [2] Claude Opus 4          — 最强推理能力，适合复杂任务
    [3] Claude Sonnet 3.5      — 成熟稳定版
    [4] 自定义模型              — 手动输入模型名称

"@
    $c = Read-Host '  请输入 [1]'
    $models = @{ '1'='claude-sonnet-4-20250514'; '2'='claude-opus-4-20250514'; '3'='claude-sonnet-3-5-20241022' }
    $model = if ($c -eq '4') { Read-Host '  输入模型名称（如 claude-sonnet-4-20250514）' } else { $models[$c] }
    if ([string]::IsNullOrEmpty($model)) { $model = 'claude-sonnet-4-20250514' }

    $dir = if ($IsWindows) { "$env:USERPROFILE\.claude" } else { "$HOME\.claude" }
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $envFile = "$dir\.env"
    $content = if (Test-Path $envFile) { Get-Content $envFile -Raw } else { '' }
    if ($content -match 'ANTHROPIC_MODEL=') {
        $content = $content -replace 'ANTHROPIC_MODEL=.*', "ANTHROPIC_MODEL=$model"
    } else {
        $content += "`nANTHROPIC_MODEL=$model"
    }
    Set-Content -Path $envFile -Value $content.TrimStart()
    $env:ANTHROPIC_MODEL = $model
    Ok "模型已配置为：$model"
}

# ===== 主流程 =====
Clear-Host
Write-Host (Color '1;35' @"
  ╔══════════════════════════════════════════╗
  ║         Claude Code 一键安装脚本         ║
  ╚══════════════════════════════════════════╝
"@)

Info '正在检测系统环境...'
$platform = Get-Platform
Ok "系统平台：$platform"
Info "需要 Claude Pro/Max/Team/Enterprise 订阅或 API 密钥"
Write-Host ""

# 安装方式
Write-Host @"
  选择安装方式：

    [1] 原生安装（推荐）— 无需额外依赖，自动更新
    [2] npm 安装        — 需要 Node.js 18+

"@
$mc = Read-Host '  请输入 [1]'
if ($mc -eq '') { $mc = '1' }
$method = if ($mc -eq '2') { 'npm' } else { 'native' }

# 模型配置
Write-Host ""
$doModel = Read-Host '  是否配置 Claude Code 使用的模型？[y/N]'
if ($doModel -eq 'y' -or $doModel -eq 'Y') { Setup-Model }

# 执行安装
try {
    Install-Code -Method $method

    # 认证
    Write-Host ""
    $doAuth = Read-Host '  是否进行账号认证？[Y/n]'
    if ($doAuth -eq '' -or $doAuth -eq 'y' -or $doAuth -eq 'Y') { Setup-Auth }

    Write-Host (Color '1;32' @"
  ┌──────────────────────────────────────┐
  │        ✓ 安装完成！                  │
  └──────────────────────────────────────┘
"@)
    Write-Host @"
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

"@
} catch {
    Write-Host (Color '1;31' "  ✗ 安装失败")
    Write-Host @"
  错误：$($_.Exception.Message)

  排查建议：
    - 检查网络连接是否正常
    - Windows 请以管理员身份运行
    - Linux/macOS 可能需要 sudo
    - 参阅官方文档：https://docs.anthropic.com/en/docs/claude-code/overview

"@
    exit 1
}
