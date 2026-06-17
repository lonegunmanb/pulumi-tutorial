# 部署 prod 并导出 State

现在切换到 `prod`。代码没有改变，但 active stack 改了，配置和 State 也随之切换。

```bash
cd /root/workspace/azure-stacks && \
source venv/bin/activate && \
pulumi stack select prod && \
pulumi preview && \
pulumi up --yes && \
pulumi stack output resource_group && \
pulumi stack output handoff_card
```{{exec}}

同一个 Project 现在已经部署出 `dev` 和 `prod` 两套资源。接着导出 `prod` 的 State，观察 Pulumi 记录了什么：

```bash
pulumi stack export --file prod-state.json && \
jq '.deployment.resources[] | {type, urn, id}' prod-state.json
```{{exec}}

再确认生产密码没有明文写进 Stack settings file：

```bash
grep -n "prod-pass-456" Pulumi.prod.yaml || echo "Secret is encrypted in Pulumi.prod.yaml"
```{{exec}}

请把 State 当成敏感运维文件看待。学习时可以导出观察；生产环境中，导出的 State 不应随意提交到 Git 或发到聊天工具里。