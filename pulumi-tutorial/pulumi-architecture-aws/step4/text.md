# 检查状态与模拟云

这一步我们要理解 Pulumi 内部的两个关键概念：
- **State**：Pulumi 保存的"上一次部署的记录"，记着已经创建的资源、它们的属性等。Pulumi 下次运行时会用新代码和旧 State 对比，判断什么需要创建、修改或删除。
- **云端资源**：真实存在于模拟器（或真实云）中的资源。

先查看 Pulumi 的 State 文件，看里面记录了哪些资源：

```bash
cd /root/workspace && \
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv'
```{{exec}}

然后查看 MiniStack 中真实存在的 S3 存储桶：

```bash
awslocal s3 ls
```{{exec}}

> **提示**：`awslocal` 是 AWS CLI 的一个包装器，它自动指向本地 MiniStack（`localhost:4566`）。如果显示 `aws: not found`（说明 AWS CLI 还在安装中），请稍等后重试，或用 `curl` 直接查询 MiniStack：
>
> ```bash
> curl -s http://localhost:4566/ | head
> ```{{exec}}

说明：这一步展示了 Pulumi 架构中的两条关键通路——**Engine 将资源信息写入 State 文件**，**Provider 把请求转发给云 API**。两者协同工作：State 是 Pulumi 的"记忆"，告诉它已经创建了什么；云端资源是"现实"，即实际存在的基础设施。