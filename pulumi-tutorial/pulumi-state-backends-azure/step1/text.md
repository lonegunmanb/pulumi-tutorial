# 登录 Azure Blob DIY Backend

miniblue 已在后台启动，初始化脚本已经创建了状态容器。先查看本次实验使用的 Backend URL。

```bash
source /root/.pulumi-state-env.sh && \
printf '%s\n' "$PULUMI_BACKEND_URL" && \
curl -s http://localhost:4566/health | jq '{edition, storage: .services.storage}'
```{{exec}}

这个 URL 使用 `azblob://` 方案。实验环境用 azlocal 创建和查看状态容器；Pulumi CLI 自己连接 Backend 时，会通过这个 URL 访问同一个 miniblue 数据面。

这里的 protocol 和 domain 是本地模拟器适配参数。真实 Azure 环境通常只需要容器 URL、storage_account 参数和 AZURE_STORAGE 凭据。

现在登录这个 Backend，并查看当前身份与 Backend 地址。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-azure && \
pulumi login "$PULUMI_BACKEND_URL" && \
pulumi whoami -v
```{{exec}}

注意这里的 AZURE_STORAGE 变量只用于访问状态容器。这个实验中的 Pulumi 程序使用 random provider，不需要 Azure resource provider 凭据。
