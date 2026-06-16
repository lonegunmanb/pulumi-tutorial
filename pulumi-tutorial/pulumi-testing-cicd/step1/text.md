# 运行基线部署

```bash
cd /root/workspace && \
pulumi preview && \
pulumi up --yes && \
pulumi stack output
```{{exec}}

后续测试会断言这些输出和资源属性。