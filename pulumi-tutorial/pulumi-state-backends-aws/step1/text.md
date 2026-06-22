# 登录 S3 DIY Backend

MiniStack 已在后台启动，初始化脚本已经创建了状态 bucket。先查看本次实验使用的 Backend URL。

```bash
source /root/.pulumi-state-env.sh && \
printf '%s\n' "$PULUMI_BACKEND_URL" && \
curl -s http://localhost:4566/_ministack/health | jq '{edition, s3: .services.s3}'
```{{exec}}

这个 URL 使用 `s3://` 方案。query string 中的 endpoint 和 path-style 参数让 Pulumi CLI 把状态写入本地 MiniStack，而不是访问真实 AWS。

现在登录这个 Backend，并查看当前身份与 Backend 地址。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-aws && \
pulumi login "$PULUMI_BACKEND_URL" && \
pulumi whoami -v
```{{exec}}

注意这里的 AWS 环境变量只用于访问状态 bucket。这个实验中的 Pulumi 程序使用 random provider，不需要 AWS 资源 provider 凭据。
