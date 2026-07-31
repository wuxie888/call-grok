# Security

## Credential boundary

有事叫 Grok 不读取、打印、复制或上传 Grok 的凭据文件。安装器只从 `https://x.ai/cli/install.sh` 下载，登录使用 Grok CLI 官方 OAuth 或 device-auth 流程，最终授权由用户完成。

请不要在 Issue、截图或日志中提交 token、API key、Cookie 或登录文件。如果秘密已暴露，请先在对应服务中撤销，再报告问题。

## Reporting a vulnerability

敏感问题请使用 GitHub 仓库的 **Security → Report a vulnerability** 私密报告。非敏感缺陷可直接提交 Issue。报告请包含影响版本、复现步骤和预期行为，但不要包含真实凭据。

## Paid-action boundary

Imagine 视频可能消耗周配额或 API 额度。插件要求在每一次生成前重新确认输入、提示词、时长、分辨率与“只调用一次”，失败不自动重试。
