# 用 StackReference 跨项目读取输出

这一步展示 Pulumi 在真实场景中的常见模式：一个 Project 创建基础设施资源，另一个 Project（或应用程序）读取这些资源的信息并使用它们。Pulumi 通过 `StackReference` 机制支持这种"上游-下游"的依赖关系。

进入下游 Project（这是一个消费者项目）。它不会创建 miniblue 资源，只通过 StackReference 读取上游 `azure-infra` 对应 Stack 的 Outputs：

```bash
cd /root/workspace/azure-consumer && \
cat Pulumi.yaml && \
sed -n '1,80p' __main__.py
```{{exec}}

观察代码中的关键部分：`StackReference` 里的项目名 `projects-stacks-azure-infra` 必须与上游 `Pulumi.yaml` 的 `name` 字段完全一致；对于本地后端，组织名前缀统一写作 `organization`。

先创建并部署下游 `dev` Stack。注意它会自动读取上游 `azure-infra` 的 `dev` 输出：

```bash
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi up --yes && \
pulumi stack output source_resource_group && \
pulumi stack output source_handoff_card
```{{exec}}

再创建并部署下游 `prod` Stack。当前 Stack 变成 `prod` 时，StackReference 会自动读取上游的 `prod` 输出（而非 `dev` 输出）：

```bash
{ pulumi stack init prod || pulumi stack select prod; } && \
pulumi up --yes && \
pulumi stack output source_resource_group && \
pulumi stack output source_key_vault && \
pulumi stack output referenced_secret --show-secrets
```{{exec}}

说明：观察输出中引用的资源名，它们来自不同的 Stack（`dev` 和 `prod` 各自有自己的资源）。这展示了 Pulumi 如何灵活地通过 Stack 隔离不同环境的资源，同时支持跨项目的声明式依赖。

最后清理两个 Project 的所有资源和 miniblue 模拟器：

```bash
cd /root/workspace/azure-consumer && \
pulumi stack select dev && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace/azure-infra && \
pulumi stack select dev && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace && \
docker compose down
```{{exec}}

总结这一章的学习：
- **Project**：一份 Pulumi 代码库，定义了基础设施的资源。
- **Stack**：同一个 Project 的不同命名环境（dev、prod 等），拥有独立的配置和状态。
- **Config & Secret**：Stack 的配置参数，其中 Secret 会被加密存储。
- **State**：记录已部署资源的内部文件，Pulumi 通过对比新代码和旧 State 来判断增删改。
- **Output**：Stack 暴露给外部的值，其他项目可以通过 StackReference 读取。
- **StackReference**：跨项目引用，支持声明式的项目间依赖。