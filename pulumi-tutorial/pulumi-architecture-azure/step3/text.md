# 预览并部署资源

激活 Python 虚拟环境，然后运行预览：

```bash
cd /root/workspace
source venv/bin/activate
pulumi preview
```{{exec}}

> 提示：本实验使用空口令的本地后端。如果终端提示 `Enter your passphrase to unlock config/secrets`，直接按回车（即空口令）即可继续；连续两次提示也都直接回车。
>
> 想彻底免去提示，可以先执行 `export PULUMI_CONFIG_PASSPHRASE=""`{{exec}} 再运行后续命令（新开的终端默认已写入 `~/.bashrc`，本次提示是因为终端在环境准备完成前就已打开）。

执行部署：

```bash
pulumi up --yes
pulumi stack output
```{{exec}}

观察 `architecture-rg` 与 `engine-token` 两个资源。`engine-token` 显式依赖 `architecture-rg`，所以 Engine 会先创建资源组，再创建 Key Vault Secret。