# 启动 miniblue Azure 模拟器

先启动 miniblue。镜像已经固定为 `ghcr.io/lonegunmanb/miniblue:sha-11ef0e8`：

```bash
cd /root/workspace && \
docker pull ghcr.io/lonegunmanb/miniblue:sha-11ef0e8 && \
docker compose up -d && \
curl -s http://localhost:4566/health | jq .
```{{exec}}

把 `azlocal` 从容器复制出来，后续用它验证 Azure 风格资源：

```bash
cd /root/workspace && \
CID=$(docker compose ps -q miniblue) && \
docker cp "$CID:/azlocal" /usr/local/bin/azlocal && \
chmod +x /usr/local/bin/azlocal && \
azlocal health
```{{exec}}