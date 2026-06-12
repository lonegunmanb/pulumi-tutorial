# 预览并部署资源

激活 Python 虚拟环境，然后运行预览：

```bash
cd /root/workspace
source venv/bin/activate
pulumi preview
```{{exec}}

执行部署：

```bash
pulumi up --yes
pulumi stack output
```{{exec}}

观察 `architecture-rg` 与 `engine-token` 两个资源。`engine-token` 显式依赖 `architecture-rg`，所以 Engine 会先创建资源组，再创建 Key Vault Secret。