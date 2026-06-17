# 启动 miniblue Azure 模拟器

这一步的目标，是先搭一个“本地练习场”，让你不用真实 Azure 账号也能跑完整个实验。`miniblue` 就是这个本地模拟器：它会在你的机器上提供 Azure 风格的 API，供 Pulumi 调用。

先启动 `miniblue`。镜像已经固定为 `ghcr.io/lonegunmanb/miniblue:sha-11ef0e8`：

```bash
cd /root/workspace && \
docker pull ghcr.io/lonegunmanb/miniblue:sha-11ef0e8 && \
docker compose up -d && \
curl -s http://localhost:4566/health | jq .
```{{exec}}

启动完成后，再把 `azlocal` 从容器里复制出来。你可以把它理解成“面向这个本地 Azure 模拟器的命令行工具”，后面会用它来验证资源是否真的被创建出来：

```bash
cd /root/workspace && \
CID=$(docker compose ps -q miniblue) && \
docker cp "$CID:/azlocal" /usr/local/bin/azlocal && \
chmod +x /usr/local/bin/azlocal && \
azlocal health
```{{exec}}

说明要点：
- `docker pull` 和 `docker compose up -d` 负责把模拟器下载并启动。
- `curl .../health` 用来确认模拟器已经准备好，可以接收请求。
- `azlocal` 类似 Azure CLI，但它访问的是本地模拟器，不是真实 Azure。