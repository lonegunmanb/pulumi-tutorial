# 认识 Project 与启动 MiniStack

先启动本地 AWS 模拟器。MiniStack 会在 `localhost:4566` 暴露 AWS 风格 API：

```bash
cd /root/workspace
docker compose up -d
docker compose ps
```{{exec}}

查看上游 Project 的结构：

```bash
cd /root/workspace/aws-infra
ls -la
cat Pulumi.yaml
sed -n '1,120p' index.ts
```{{exec}}

注意 `Pulumi.yaml` 定义 Project，`index.ts` 读取当前 Stack 的 Config，并把 Bucket 名称、环境名和 Secret 输出为 Stack Outputs。