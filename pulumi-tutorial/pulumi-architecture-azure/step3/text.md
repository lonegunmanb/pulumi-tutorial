# 预览并部署资源

现在开始真正让 Pulumi 干活。这里有两个阶段要区分清楚：
- `preview` 只是先看计划，告诉你“如果执行，会发生什么”。
- `up` 才会真的去创建资源。

先激活 Python 虚拟环境，然后运行预览：

```bash
cd /root/workspace && \
source venv/bin/activate && \
pulumi preview
```{{exec}}

> 提示：本教程统一使用空口令的本地后端，并已写入 `~/.bashrc`，**新开的终端不会再提示口令**。
>
> 但当前这个终端在环境准备完成前就打开了，所以上面的 `pulumi preview` 可能提示 `Enter your passphrase to unlock config/secrets`——直接按回车（空口令）即可，连续两次提示都回车。为让**当前终端**也记住空口令，只需手动执行一次：

```bash
export PULUMI_CONFIG_PASSPHRASE=""
```{{exec}}

如果 `preview` 里看到的是要创建资源，就继续执行部署。这里把 `pulumi up` 与 `pulumi stack output` 拆成两个代码块分别点击，避免部署过程中的交互界面吞掉下一行命令：

```bash
source venv/bin/activate && \
pulumi up --yes
```{{exec}}

```bash
pulumi stack output
```{{exec}}

部署后再读取输出结果：

- `architecture-rg` 可以理解为这组资源放在哪个“资源容器”里。
- `engine-token` 是一个依赖前置资源的机密值。

观察 `architecture-rg` 与 `engine-token` 的关系：`engine-token` 显式依赖 `architecture-rg`，所以 Engine 会先创建资源组，再创建 Key Vault Secret。这个顺序不是你手工控制的，而是 Pulumi 根据依赖关系自动安排的。