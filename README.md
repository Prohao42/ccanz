# Claude Code 一键安装脚本

全中文交互 · 跨平台 · 零依赖 · 支持模型配置

## 一句话安装

```powershell
# Windows PowerShell
irm https://raw.githubusercontent.com/Prohao42/ccanz/main/install.ps1 | iex
```

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/Prohao42/ccanz/main/install.sh | bash
```

## 特性

- **全中文交互** — 安装提示、菜单选项全部中文
- **跨平台** — Windows / macOS / Linux / WSL 自适应
- **官方原生安装** — 无需 Node.js，后台自动更新
- **模型配置** — 安装时可选 Sonnet 4 / Opus 4 / 自定义模型
- **认证引导** — 浏览器 OAuth / API Key 自动配置
- **管道安全** — 支持 `irm | iex` 和 `curl | bash` 远程执行

## 前置要求

- **Claude 订阅**: Pro ($20/月) / Max / Team / Enterprise
- **或 API 密钥**: 从 [console.anthropic.com](https://console.anthropic.com) 获取

## 使用方式

### 远程一行命令

```powershell
# Windows
irm https://raw.githubusercontent.com/Prohao42/ccanz/main/install.ps1 | iex
```

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/Prohao42/ccanz/main/install.sh | bash
```

### 本地运行

```bash
git clone https://github.com/Prohao42/ccanz.git
cd ccanz

# Windows
.\install.ps1

# macOS / Linux / WSL
bash install.sh
```

## 安装流程

```
启动
 ├─ 系统平台检测
 ├─ 选择安装方式（原生 / npm）
 ├─ 配置模型（可选）
 ├─ 自动安装（官方安装器）
 ├─ 验证安装 (claude --version)
 ├─ 账号认证（可选）
 └─ 完成 ✓
```

## 配置模型

安装过程中可选择 Claude Code 使用的模型：

| 选项 | 模型 | 适用场景 |
|------|------|---------|
| 1 | Claude Sonnet 4 | 日常开发，速度与质量的平衡 |
| 2 | Claude Opus 4 | 复杂任务，最强推理能力 |
| 3 | Claude Sonnet 3.5 | 成熟稳定版 |
| 4 | 自定义 | 手动输入模型名称 |

模型配置保存在 `~/.claude/.env` 文件中，也可后续手动编辑。

## 安装后

```bash
claude --version    # 查看版本
claude doctor       # 运行诊断
cd my-project && claude   # 开始使用
```

## 文件结构

```
├── install.ps1    # Windows PowerShell 安装脚本
├── install.sh     # macOS / Linux / WSL 安装脚本
└── README.md      # 本文件
```

## 注意事项

- 原生安装会自动后台更新，无需手动操作
- Windows 建议使用 Windows Terminal + PowerShell 7+
- 如遇 PATH 问题，重启终端或重新登录
- 企业环境可能需要配置代理
- 模型配置写入 `~/.claude/.env`，也可手动编辑
