# 导出与导入 State

Pulumi 提供专门命令导出 State。先切回 dev Stack，并把当前 checkpoint 导出到本地文件。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-aws && \
pulumi stack select dev && \
pulumi stack export --file state-dev.json && \
jq '{version, resourceCount: (.deployment.resources | length)}' state-dev.json
```{{exec}}

导出的文件适合排障、备份验证或受控修复。没有加 --show-secrets 时，secret 仍以加密形式保留。

把刚才导出的文件重新导入当前 Stack，然后预览一次确认没有基础设施变化。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-aws && \
pulumi stack import --file state-dev.json && \
pulumi preview
```{{exec}}

在真正切换 Backend 时，也应通过 export 与 import 完成，而不是直接复制对象存储里的 JSON 文件。
