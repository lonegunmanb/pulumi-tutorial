# 创建与切换堆栈

```bash
cd /root/workspace
pulumi stack init prod
pulumi config set prefix prod
pulumi stack select dev
pulumi config get prefix
pulumi stack select prod
pulumi config get prefix
```{{exec}}

同一个 Project 可以承载多个 Stack，每个 Stack 拥有独立配置与状态。