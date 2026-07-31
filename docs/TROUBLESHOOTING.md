# 排错与支持

> English summary: verify platform and shell first, then separate Codex plugin discovery, Grok CLI installation, OAuth, X retrieval, local media dependencies, ZDR storage, and quota. Never post credential files or tokens in an issue.

## 先运行无敏感信息的检查

```bash
codex plugin list --json
grok --version
node --version
```

视频路径再检查：

```bash
jq --version
ffmpeg -version
ffprobe -version
```

这些命令不需要读取凭据文件

## `codex plugin` 不存在

当前 Codex 版本不支持 Plugin Marketplace，或终端上的 `codex` 不是你以为的那个安装

先运行：

```bash
which codex
codex --version
codex plugin --help
```

Windows PowerShell 可用 `Get-Command codex` 替代 `which codex`

## 插件已安装，但 `$call-grok` 没触发

1. 运行 `codex plugin list --json` 确认 `call-grok@call-grok` 处于 installed/enabled
2. 新建 Codex 任务，不要只在安装前的旧任务里重试
3. 明确写出 `$call-grok`
4. 若仍不触发，记录 Codex 版本、操作系统和安装命令，不要附带凭据或配置全文

## Windows PowerShell 上插件执行失败

`v1.1.0` 已经为 bootstrap、X 检索和 Imagine 视频提供原生 PowerShell 执行器。如果仍失败，先确认安装的是 `v1.1.0` 而不是旧版

xAI 官方 PowerShell 安装方式是：

```powershell
irm https://x.ai/cli/install.ps1 | iex
```

在原生 PowerShell 中应分别使用 `grok-bootstrap.ps1`、`run-x-intel.ps1` 和 `run-video.ps1`，不要绕到 Git Bash 执行 `.sh`

如果仍失败：

- 运行 `Get-Command grok`、`grok --version` 和 `codex plugin list --json`
- 确认 Codex 与 Grok 在同一个 Windows 用户环境，没有一个在 WSL、另一个在 Windows
- X 路径确认 `node` 可用；视频路径确认 `ffmpeg` 和 `ffprobe` 可用
- 记录脱敏错误并提交 Issue，但不要提交凭据或本机私有路径

## Grok CLI 缺失

`$call-grok` 应返回 `missing_cli`，说明官方安装位置并等待授权

如果已经安装但找不到：

- 确认 `grok --version`
- 确认当前 shell 的 `PATH`
- macOS/Linux 默认路径是 `~/.grok/bin/grok`
- 不要从非官方镜像随意下载替代二进制

## 登录结束，但第一个任务报鉴权错误

登录流程完成和当前任务真的获得服务端鉴权是两件事

- 重新运行官方 `grok login`
- 浏览器打开后核对账号，自己完成最终授权
- 远程/无浏览器环境使用 `grok login --device-auth`
- 不要读取、打印或提交 Grok 凭据文件

## X 搜索返回 `partial` 或 `failed`

常见原因：

- Grok 原生 X 搜索在当前账号/任务中不可用
- 帖子被删除或不可访问
- 返回项目没有完整 status URL
- 账号 handle、日期或关键词太模糊
- 结构化输出有尾随文字，已尝试恢复但仍无法解析

插件不应该悄悄换成普通 Web Search 再宣称已覆盖 X

## 视频路径缺少依赖

macOS/Linux/WSL 的 Bash 执行器需要：

- `jq`
- `ffmpeg`
- `ffprobe`

Windows PowerShell 执行器使用系统 JSON 解析，只需要：

- `ffmpeg`
- `ffprobe`

只有依赖存在才会进入视频执行门，且仍需要你对那一次生成做新的明确确认

## Zero Data Retention / `output.upload_url`

如果返回 Zero Data Retention 与 `output.upload_url` 错误，插件必须停止，不得重试

只有两条由用户选择的路径：

1. 明确切换为 Opt in，允许 CLI 直接交付视频
2. 保持 Opt out/ZDR，配置自己控制的 R2/S3 上传地址

插件不会自动更改账号隐私或存储设置

## 额度与费用

- X 搜索结果中的 `_run.cost_usd` 只是该次运行元数据，不是剩余周配额
- 优先查看 Grok `/usage` 或 xAI 账号页
- 插件不创建 API key、开启充值或修改账单
- 视频失败后重试是新的可能付费行动，需要重新确认

## 提交 Issue 时带什么

可以提供：

- 操作系统与 CPU 架构
- shell（zsh、bash、WSL、PowerShell、Git Bash）
- Codex 版本
- Grok CLI 版本
- 失败的能力（bootstrap、X、video）
- 去除用户名、私有路径和账号信息后的最小错误

不要提供：

- token、API key、Cookie
- Grok 凭据文件
- 未脱敏的会话、本机路径或私有链接

敏感漏洞请使用 GitHub 的私密安全报告，不要开公开 Issue
