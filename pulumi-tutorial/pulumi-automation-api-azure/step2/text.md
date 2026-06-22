# 用 SDK 生成预览

Automation API 入口在 automation.ts。它使用 LocalWorkspace 选择 dev Stack，写入配置，并调用 preview。

```bash
cd /root/workspace && \
sed -n '1,220p' automation.ts && \
npx ts-node --transpile-only automation.ts preview dev
```{{exec}}

注意输出末尾的 JSON。它来自 SDK 返回值，不是从终端日志里截取出来的文本。