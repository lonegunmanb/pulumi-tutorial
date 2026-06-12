# 观察资源 URN

```bash
cd /root/workspace
pulumi up --yes
pulumi stack export | jq -r '.deployment.resources[].urn'
```{{exec}}

URN 是 Pulumi 识别资源身份的关键，它由 Stack、Project、资源类型、父子关系与逻辑名共同决定。