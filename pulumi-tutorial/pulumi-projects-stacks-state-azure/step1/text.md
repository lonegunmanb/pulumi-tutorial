# 认识 Project 与启动 miniblue

先启动本地 Azure 风格模拟器。miniblue 会在 `localhost:4566` 暴露 API：

```bash
cd /root/workspace && \
docker compose up -d && \
docker compose ps
```{{exec}}

查看上游 Project 的结构：

```bash
cd /root/workspace/azure-infra && \
ls -la && \
cat Pulumi.yaml && \
sed -n '1,180p' __main__.py
```{{exec}}

这个 Project 使用 Python Dynamic Provider 调用 miniblue API。重点不在 Azure API 细节，而在 Project、Stack、Config、Secret、Output 与 State 的关系。