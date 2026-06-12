# 启动 MiniStack 云端工地

MiniStack 会在本地 `4566` 端口模拟 AWS API。先启动它并检查健康状态：

```bash
cd /root/workspace
docker compose up -d
curl -s http://localhost:4566/_ministack/health | jq .
```{{exec}}

把它想象成本章的“云端工地”：Pulumi Provider 之后会把 S3 API 请求发到这里，而不是发到真实 AWS。