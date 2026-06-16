# 运行 CLI 基线

```bash
cd /root/workspace && \
pulumi preview && \
pulumi up --yes && \
pulumi destroy --yes
```{{exec}}

Automation API 最终要用代码复现并编排这些操作。