# 预览并部署资源

这一步我们要让 Pulumi 把代码转换成实际操作。Pulumi Engine 的工作流程是：读取程序代码 → 计算需要创建/修改/删除的资源 → 生成一个执行计划 → 获得你的确认后执行。

先运行 preview 来查看 Pulumi 将要做什么（计划阶段，不会真正改动任何资源）：

```bash
cd /root/workspace && \
pulumi preview
```{{exec}}

> **口令提示**：本教程统一使用空口令的本地后端。如果 preview 提示 `Enter your passphrase to unlock config/secrets`，直接按回车（空口令）即可。为了让当前终端也记住这个口令，可以执行：

```bash
export PULUMI_CONFIG_PASSPHRASE=""
```{{exec}}

如果 preview 显示只需创建 S3 Bucket，那就执行部署。以下把部署和输出查询拆成两个代码块，避免部署过程中的交互界面干扰后续命令：

```bash
pulumi up --yes
```{{exec}}

查看部署的结果和输出：

```bash
pulumi stack output
```{{exec}}

说明：
- **`+` 符号**：表示 Engine 判断这个资源在旧 State 中不存在，所以需要**创建**。
- **`pulumi preview`**：只计划，不执行。用来提前检查会有什么改动。
- **`pulumi up --yes`**：执行部署，`--yes` 意思是不再询问确认，直接部署。
- **`pulumi stack output`**：显示此 Stack 导出给外部使用的值（例如创建的资源 ID）。