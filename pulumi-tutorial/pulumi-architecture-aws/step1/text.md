# 启动 MiniStack 云端工地

这一步的目标：为练习搭建一个"离线"的 AWS 环境，这样你就不需要真实的 AWS 账户或网络连接来学习 Pulumi。

我们会启动 **MiniStack**——一个本地模拟器，它运行在你电脑的 `localhost:4566`，模拟 AWS 的 API 接口。之后 Pulumi 发送的云资源请求（比如创建 S3 存储桶）会被发送到这个本地模拟器，而不是真实的 AWS。

先启动 MiniStack 并检查它是否正常运行：

```bash
cd /root/workspace && \
docker compose up -d && \
curl -s http://localhost:4566/_ministack/health | jq .
```{{exec}}

说明：
- `docker compose up -d`：启动 MiniStack 容器（在后台运行）。
- `curl -s http://localhost:4566/_ministack/health | jq .`：查询 MiniStack 的健康状态，确保它已经启动并可以处理请求。