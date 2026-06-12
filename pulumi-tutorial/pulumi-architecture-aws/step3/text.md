# 预览并部署资源

先让 Engine 读取程序并计算计划：

```bash
cd /root/workspace
pulumi preview
```{{exec}}

> 提示：本实验使用空口令的本地后端。如果终端提示 `Enter your passphrase to unlock config/secrets`，直接按回车（即空口令）即可继续；连续两次提示也都直接回车。
>
> 想彻底免去提示，可以先执行 `export PULUMI_CONFIG_PASSPHRASE=""`{{exec}} 再运行后续命令（新开的终端默认已写入 `~/.bashrc`，本次提示是因为终端在环境准备完成前就已打开）。

如果预览中只看到创建 S3 Bucket 的计划，就执行部署：

```bash
pulumi up --yes
pulumi stack output
```{{exec}}

观察输出中的 `+` 符号。它表示 Engine 判断这些资源在旧 State 中不存在，需要创建。