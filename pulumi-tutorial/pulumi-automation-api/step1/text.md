# 运行 CLI 基线

MiniStack 已由后台初始化脚本启动，并通过健康检查后才进入本步骤。现在用 CLI 执行同一份 Pulumi 程序，确认 Pulumi 项目、Stack 配置和本地 AWS 模拟器都已经可用。

这里先跑 CLI，并不是因为使用 Automation API 前必须先手动部署一次。它是一个对照实验：先确认这份程序可以完成预览、部署、读取输出和销毁；下一步再看 Automation API 如何用代码调用同一套生命周期。这样如果后面的 SDK 步骤出错，问题范围就会更清楚。

```bash
cd /root/workspace && \
pulumi stack select dev && \
pulumi preview && \
pulumi up --yes && \
pulumi stack output --json && \
pulumi destroy --yes
```{{exec}}

这一步完成后，dev Stack 仍然存在，但里面的资源已经删除。下一步会由 Automation API 接管同一个工作区。