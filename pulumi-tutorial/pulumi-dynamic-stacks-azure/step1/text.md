# 读取网络配置矩阵

miniblue 已经在后台启动。先确认本地 Azure 模拟器健康，并查看 dev/prod 的网络配置：

```bash
cd /root/workspace && \
curl -s http://localhost:4566/health | jq . && \
printf '\n--- Pulumi.dev.yaml ---\n' && sed -n '1,240p' Pulumi.dev.yaml && \
printf '\n--- Pulumi.prod.yaml ---\n' && sed -n '1,260p' Pulumi.prod.yaml && \
printf '\n--- index.ts ---\n' && sed -n '1,260p' index.ts
```{{exec}}

先观察配置矩阵。dev 使用一个应用子网，prod 使用应用、服务和数据三个子网。

再看程序里的 `enablePrivateSubnet`。当它为 true 时，程序会创建私有子网 NSG，并把私有子网关联到它。

最后确认当前项目已经有 Git 基线，后面会用它观察配置变更：

```bash
git status --short && git log --oneline -1
```{{exec}}
