# 预览并部署资源

先让 Engine 读取程序并计算计划：

```bash
cd /root/workspace
pulumi preview
```{{exec}}

> 提示：本实验使用空口令的本地后端。上面这个 `pulumi preview` 可能提示 `Enter your passphrase to unlock config/secrets`，直接按回车（空口令）即可，连续两次提示都回车。
>
> 提示出现的原因是终端在环境准备脚本写入 `PULUMI_CONFIG_PASSPHRASE` 之前就打开了。为避免多行命令被口令提示“吞掉第二行”，后续代码块都在开头加了 `export PULUMI_CONFIG_PASSPHRASE=""`；你也可以在本终端先手动执行 `export PULUMI_CONFIG_PASSPHRASE=""`{{exec}} 一劳永逸。

如果预览中只看到创建 S3 Bucket 的计划，就执行部署：

```bash
export PULUMI_CONFIG_PASSPHRASE=""
pulumi up --yes
pulumi stack output
```{{exec}}

观察输出中的 `+` 符号。它表示 Engine 判断这些资源在旧 State 中不存在，需要创建。