# 用 StackReference 跨项目读取输出

这一节把前面学过的内容串起来：一个 Project 负责创建基础设施，另一个 Project 不重复创建，而是直接读取前一个 Project 的输出结果继续使用。

Pulumi 用 `StackReference` 支持这种“跨项目引用”。你可以把它理解成：**下游项目去读取上游项目某个 Stack 已经导出的 Output。**

先进入下游 Project。它不会创建 AWS 资源，只读取上游 `aws-infra` 对应 Stack 的 Outputs。

关键点：`StackReference` 里的 `projects-stacks-aws-infra` 必须与上游 `Pulumi.yaml` 的 `name` 字段完全一致；本地后端的组织名前缀固定写作 `organization`。

```bash
cd /root/workspace/aws-consumer && \
cat Pulumi.yaml && \
sed -n '1,120p' index.ts
```{{exec}}

先创建并部署下游 `dev` Stack。它会读取 `organization/projects-stacks-aws-infra/dev`，也就是上游 `dev` 环境暴露出来的输出：

```bash
{ pulumi stack init dev || pulumi stack select dev; } && \
pulumi up --yes && \
pulumi stack output sourceBucket && \
pulumi stack output sourceHandoffCard
```{{exec}}

再创建并部署下游 `prod` Stack。因为当前 Stack 变成 `prod`，`StackReference` 会自动切换去读取上游的 `prod` 输出：

```bash
{ pulumi stack init prod || pulumi stack select prod; } && \
pulumi up --yes && \
pulumi stack output sourceBucket && \
pulumi stack output sourceHandoffCard && \
pulumi stack output referencedSecret --show-secrets
```{{exec}}

这正是 Stack 的价值所在：同一份下游代码，只要当前 Stack 变了，它引用到的上游环境也会跟着切换。

最后清理两个 Project 的资源和 MiniStack：

```bash
cd /root/workspace/aws-consumer && \
pulumi stack select dev && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace/aws-infra && \
pulumi stack select dev && pulumi destroy --yes && \
pulumi stack select prod && pulumi destroy --yes && \
cd /root/workspace && \
docker compose down
```{{exec}}

回头总结这一章：
- **Project** 是一套基础设施代码工程。
- **Stack** 是这套工程在某个环境下的一次独立实例。
- **Config / Secret** 决定这个环境的参数，其中 Secret 会被加密保存。
- **State** 记录已经部署出的现实资源。
- **Output** 是暴露给外部使用的结果。
- **StackReference** 让不同 Project 之间可以安全地传递这些结果。