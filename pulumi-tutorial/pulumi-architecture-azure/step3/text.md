# 预览并部署资源

激活 Python 虚拟环境，然后运行预览：

```bash
cd /root/workspace
source venv/bin/activate
pulumi preview
```{{exec}}

> 提示：本实验使用空口令的本地后端。上面这个 `pulumi preview` 可能提示 `Enter your passphrase to unlock config/secrets`，直接按回车（空口令）即可，连续两次提示都回车。
>
> 提示出现的原因是终端在环境准备脚本写入 `PULUMI_CONFIG_PASSPHRASE` 之前就打开了。为避免多行命令被口令提示“吞掉第二行”，后续代码块都在开头加了 `export PULUMI_CONFIG_PASSPHRASE=""`；你也可以在本终端先手动执行 `export PULUMI_CONFIG_PASSPHRASE=""`{{exec}} 一劳永逸。

执行部署：

```bash
export PULUMI_CONFIG_PASSPHRASE=""
pulumi up --yes
pulumi stack output
```{{exec}}

观察 `architecture-rg` 与 `engine-token` 两个资源。`engine-token` 显式依赖 `architecture-rg`，所以 Engine 会先创建资源组，再创建 Key Vault Secret。