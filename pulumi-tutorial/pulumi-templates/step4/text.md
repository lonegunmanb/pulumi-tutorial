# 运行 preview 与 up

生成项目只是第一步。一个合格 template 应该能让新项目继续安装依赖并执行 Pulumi 工作流。

```bash
source /root/.pulumi-templates-env.sh && \
cd /root/workspace/templates-lab/orders-service && \
npm install --no-audit --no-fund && \
pulumi preview && \
pulumi up --yes && \
pulumi stack output
```{{exec}}

输出里可以看到 generatedProject、projectDescription、serviceResourceName 等值。tokenPreview 仍会保持 secret 传播，不会直接暴露完整 token。
