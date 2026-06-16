# 预览并部署资源

先让 Engine 读取程序并计算计划：

```bash
cd /root/workspace && \
pulumi preview
```{{exec}}

> 提示：本教程统一使用空口令的本地后端，并已写入 `~/.bashrc`，**新开的终端不会再提示口令**。
>
> 但当前这个终端在环境准备完成前就打开了，所以上面的 `pulumi preview` 可能提示 `Enter your passphrase to unlock config/secrets`——直接按回车（空口令）即可，连续两次提示都回车。为让**当前终端**也记住空口令，只需手动执行一次：

```bash
export PULUMI_CONFIG_PASSPHRASE=""
```{{exec}}

如果预览中只看到创建 S3 Bucket 的计划，就执行部署。这里把 `pulumi up` 与 `pulumi stack output` 拆成两个代码块分别点击，避免部署过程中的交互界面吞掉下一行命令：

```bash
pulumi up --yes
```{{exec}}

```bash
pulumi stack output
```{{exec}}

观察输出中的 `+` 符号。它表示 Engine 判断这些资源在旧 State 中不存在，需要创建。