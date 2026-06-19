# Functions 四类函数（AWS / MiniStack）

本实验用 **MiniStack** 在本地模拟 AWS，把 Pulumi 的四类函数全部跑一遍：

- **Provider functions**：向云 API 查询一个值，对比 **direct form** 与 **output form**。
- **Get functions**：引用一个**不归 Pulumi 管**的既有资源。
- **Function serialization**：把一段 JavaScript 闭包序列化成 **AWS Lambda**，部署到 MiniStack 的 Node.js 运行时并真正 `invoke`。
- **Resource methods**：在一个**由 Pulumi 管理**的 EKS 集群上调用 `getKubeconfig()`。

实验不需要真实 AWS 账号——Lambda 在 MiniStack 的 Node.js 运行时里执行，EKS 由一个真实的 k3s 容器模拟。为此本实验的 MiniStack 额外挂载了 **Docker socket** 并把 Lambda 设为 `docker` 执行模式。环境准备脚本（`init/background.sh`）会自动启动 MiniStack、等它**健康检查通过后**才让你进入实验，并预先配好指向 MiniStack 的 default AWS provider，因此进来即可直接开始。

> 关于口令提示：本实验使用空口令的本地后端。第一次运行 `pulumi` 命令时，终端可能会提示 `Enter your passphrase to unlock config/secrets`——这是因为终端在环境准备脚本写入 `PULUMI_CONFIG_PASSPHRASE` 之前就打开了。直接按回车（空口令）即可继续，连续两次提示也都按回车。
