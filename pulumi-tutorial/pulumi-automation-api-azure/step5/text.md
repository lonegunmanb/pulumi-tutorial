# 销毁环境并复盘

最后清理 dev 和 review 两个 Stack 中的资源，并停止本地 HTTP 服务。

```bash
cd /root/workspace && \
npx ts-node --transpile-only automation.ts destroy dev && \
npx ts-node --transpile-only automation.ts destroy review && \
(kill "$(cat /tmp/automation-api-server.pid)" 2>/dev/null || true)
```{{exec}}

Automation API 没有绕过 Pulumi 的生命周期。它只是把 preview、up、refresh、outputs 和 destroy 这些动作变成应用程序可以组合的 SDK 调用。