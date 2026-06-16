# 运行基础项目

```bash
cd /root/workspace && \
pulumi preview && \
pulumi up --yes && \
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv'
```{{exec}}

先观察平铺资源在状态图中的表现。