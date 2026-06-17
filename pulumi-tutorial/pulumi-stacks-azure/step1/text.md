# 启动 miniblue 与认识 Project

这一步先启动本地 Azure 风格模拟器 `miniblue`。它会在 `localhost:4566` 接收 API 请求，让你不用真实 Azure 账号也能练习 Stack 生命周期。

```bash
cd /root/workspace && \
docker compose up -d && \
curl -s http://localhost:4566/health | jq .
```{{exec}}

接着查看 Pulumi Project。先把 Project 理解成“同一套基础设施代码工程”，而 Stack 是这套工程的某个独立环境实例。

```bash
cd /root/workspace/azure-stacks && \
ls -la && \
cat Pulumi.yaml && \
sed -n '1,220p' __main__.py
```{{exec}}

重点观察两处：

- `Pulumi.yaml` 里的 `name: stacks-azure-lab` 是 Project 名，后面配置键会带上这个前缀。
- `__main__.py` 使用 `pulumi.get_stack()` 读取当前 Stack，并把 Stack 名拼进 Resource Group 与 Key Vault 名称里。

这意味着：同一份代码部署到 `dev` 和 `prod`，会得到两套不同名称、不同配置、不同 State 的资源。