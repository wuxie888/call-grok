# 第一次成功

> English quick path: install the pinned marketplace and plugin, start a new Codex task, and ask `$call-grok` for a bounded X-native investigation. A successful result includes resolvable X status URLs or an explicit coverage gap. Platform support is listed in the root README.

这份指南的终点不是“已安装”，而是在一个新 Codex 任务中完成一次可核验的 X 原生调研

## 0. 先确认环境

- 支持 Plugin Marketplace 的 Codex
- 可登录 Grok 的账号
- macOS Apple Silicon 是当前唯一完成端到端验证的环境
- Linux/WSL 路径仍需更多真机验收
- Grok Build 官方支持 Windows PowerShell，本插件 `v1.1.0` 已提供对应 `.ps1` 执行器并通过 GitHub `windows-latest` 离线 CI；这不等于真实 Windows Grok 账号任务验收

不确定时先查看 [README 平台矩阵](../README.md)

## 1. 安装锁定版本

```bash
codex plugin marketplace add wuxie888/call-grok --ref v1.2.0
codex plugin add call-grok@call-grok
```

锁定 Tag 意味着你不会在不知情的情况下跟随 `main` 上的未发布变化

## 2. 新建 Codex 任务

安装完成后新建任务，不要用安装前已加载的旧任务作为首次验收

```text
用 $call-grok 查一下 X 上最近大家怎么评价这个项目
```

你可以在后面补充：

- 项目官方 X handle
- 希望覆盖的日期范围
- 中文、英文或两者
- 你最关心的争议、上新、风险或反馈类型

## 3. 如果 Grok CLI 缺失

`$call-grok` 会先保留你的原问题，再说明将使用 xAI 官方安装器并安装到 `~/.grok/bin`

只有在你已经明确要求安装/配置，或现场同意后，它才应该安装

安装完成后，插件启动 Grok OAuth/device flow，你需要：

1. 看清楚浏览器或设备码页显示的账号
2. 自己完成最终授权
3. 如果账号不对，不要继续点击

插件不应读取或打印 Grok 凭据文件来“证明已登录”

## 4. 检查结果

一次可接受的结果至少包含：

| 项目 | 可接受标准 |
|---|---|
| X 原生检索 | 明确显示已使用；不能用普通网页搜索假装 |
| 帖子证据 | 完整 `https://x.com/.../status/...` URL |
| 作者与时间 | 保留 handle 与发布时间 |
| 事实边界 | 直接显示、作者主张、外部验证、Codex 推断分开 |
| 失败边界 | 删除、无法访问、身份不明或零结果必须直说 |
| 配额 | 如果需要查看，使用 Grok `/usage` 或 xAI 账号页，不用单次 cost 猜测 |

## 5. 安装成功但任务失败

这仍然是有用的验收结果，因为安装、登录、X 检索权限、账号额度和结果解析是不同的门

将具体错误与 [排错文档](TROUBLESHOOTING.md) 对照，不要为了“看起来成功”而自动改用其他搜索源

## English acceptance checklist

- Install the public pinned tag
- Start a new Codex task
- Invoke `$call-grok` with a real X research request
- Complete any required Grok account approval yourself
- Require native X retrieval and resolvable status URLs
- Accept explicit failure or coverage gaps; do not accept fabricated representative posts
- Keep direct evidence, author claims, external verification, and inference separate
