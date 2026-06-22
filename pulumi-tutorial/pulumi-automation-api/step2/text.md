# 用 SDK 生成预览

Automation API 入口在 automation.ts。它使用 LocalWorkspace 选择 dev Stack，写入配置，并调用 preview。

```bash
cd /root/workspace && \
sed -n '1,220p' automation.ts && \
npx ts-node --transpile-only automation.ts preview dev
```{{exec}}

命令前半段会先打印 automation.ts 的源码，后半段会真正执行预览。预览过程中出现的表格和诊断信息是 Pulumi 的运行日志；最后一段 JSON 是 automation.ts 把 stack.preview 返回的结果对象打印出来，方便平台后端继续处理。