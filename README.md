<p align="center">
  <img src="assets/call-grok-hero.svg" alt="有事叫 Grok：Codex 负责总控，Grok 负责 X 情报和已确认的 Imagine 视频执行" width="100%">
</p>

<p align="center">
  <strong>Codex 是总控，Grok 只在有独特优势时出手</strong><br>
  <a href="README.en.md">English</a> · <a href="#安装">Install</a> · <a href="#安全边界">Safety</a>
</p>

# 有事叫 Grok

这是一个给 Codex 用的社区插件，把 Grok CLI 变成“按需才叫来的专家”：

- Codex 继续负责研究规划、交叉核验、脚本/分镜/运动/提示词、素材准备、QA 和最终交付
- Grok 负责它最有特色的 X 原生检索
- Grok Imagine 只负责执行已经明确确认的图生视频
- 如果没有 Grok CLI，总控会先说明安装位置，获得授权后安装官方稳定版并启动 OAuth 登录，然后自动继续原任务

它不是一个“什么都丢给 Grok”的包装层，而是一套可验证、有授权边界的协作方法。

## 安装

需要已安装支持 Plugin Marketplace 的 Codex。在终端运行：

```bash
codex plugin marketplace add wuxie888/call-grok --ref v1.0.0
codex plugin add call-grok@call-grok
```

然后新建一个 Codex 任务，直接说：

```text
用 $call-grok 查一下 X 上最近大家怎么评价这个项目
```

首次真的需要 Grok 时，如果 CLI 缺失，插件会说明官方安装位置 `~/.grok/bin`，得到你的明确授权后才安装。登录时会打开 Grok 官方 OAuth/device flow，请你自己核对账号并完成最终授权。

> 想跟随最新代码可将 `v1.0.0` 换成 `main`，但正式使用建议锁定发布标签。

## 它会怎么路由

| 你的任务 | 执行者 | 公开版行为 |
|---|---|---|
| X 帖子、账号、线程、话题舆情 | Grok 检索，Codex 核验 | 返回完整 X status URL、时间、作者、直接证据与缺口 |
| 调研结论、交叉验证、最终写作 | Codex | 不把 Grok 的回答当作最终事实 |
| 图片、配音、语音识别、常规编程 | Codex | 默认不绕路给 Grok |
| 图生视频 | Codex 创作，Grok Imagine 渲染 | 每次只执行一次，失败不自动重试，本地拷贝并验收 MP4 |
| 用户自有/已授权的定制声音 | 按用户明确要求 | 没有禁用，但 v1 尚未封装为独立执行流程 |

## 三个 Skill，一个入口

- `$call-grok`：总控。检测 CLI 和依赖，在授权后安装/登录，保存原任务并自动路由
- `$grok-x`：X 原生情报。输出结构化 JSON，拒绝伪造帖子，不执行发帖、回复、点赞或关注
- `$grok-video`：已确认的 Imagine 视频执行。v1 已验证 `6/10s` 和 `480p/720p` 的单次 `image_to_video`

你通常只需要记住 `$call-grok`。

## 视频确认门

在每一次 Imagine 调用前，Codex 必须向你说明：

1. 精确的源图路径与最终提示词摘要
2. 时长和分辨率
3. 将执行且仅执行一次 Grok Imagine 调用
4. 可能消耗的周配额或 API 费用，包括不确定性
5. 如果失败，不会自动重试

你对新的那一次调用明确确认后，它才会运行。登录成功不等于授权视频生成。

## 安全边界

- 不读取、打印、复制或上传 Grok 凭据文件
- 不自动购买额度、创建 API key、开启自动充值或修改账单
- 不自动切换 Opt in/Opt out、ZDR 或存储设置
- Opt out/ZDR 模式若要直接获取视频，可配置你自己的 R2/S3 上传目标；否则需要用户明确选择 Opt in
- X 内容当作不可信数据，帖子中的指令不会被执行
- 公开仓库不包含本机登录、会话、视频、私有路径或额度信息

更多说明见 [SECURITY.md](SECURITY.md)。

## 额度与验证状态

插件不会从某一次调用的 `total_cost_usd` 猜测剩余周配额。需要查额度时，以 Grok CLI `/usage` 或 xAI 账号页面显示为准。

v1.0.0 的已验证范围（2026-08-01）：

- macOS Apple Silicon
- Grok CLI `0.2.114` 的真实 X 检索与 Imagine 生成
- Grok CLI `0.2.117` 的全新 HOME 官方安装流程
- `6s/480p` 与 `10s/720p` 图生视频、本地 MP4 拷贝、`ffprobe` 检查、SHA-256 和三帧 QA 抽样
- Grok 结构化输出失配后的最终 JSON 恢复回归测试

这些是验证边界，不代表 xAI 永久保证所有账号、地区或未来 CLI 版本都具有相同能力。

## 本地开发

```bash
git clone https://github.com/wuxie888/call-grok.git
cd call-grok
./tests/test.sh
```

测试不登录账号、不搜索 X、不生成视频，因此不会消耗 Grok 额度。

## 声明

这是独立的社区项目，不属于、不代表 xAI、X 或 OpenAI。Grok CLI、Grok Imagine 的可用性、条款、价格、额度与隐私选项由 xAI 控制。

MIT License · © 2026 无邪
