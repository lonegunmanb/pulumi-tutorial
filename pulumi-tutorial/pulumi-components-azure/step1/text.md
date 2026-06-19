# 平铺资源：没有层级

环境初始化时已经启动 miniblue（本地 Azure 模拟器）并把它的证书加入了系统信任库，可以直接开始。

先看一眼初始程序声明了什么：

```bash
cat /root/workspace/index.ts
```{{exec}}

它在 `index.ts` 里**平铺**地声明了两个 Storage Account：`media-logs`（访问日志账户）和 `media-data`（主账户），外加一个容纳它们的 Resource Group `media-rg`。这是没有组件时的常见写法——每个资源各写一遍、各设一遍 `provider`、各打一遍标签。

部署初始程序：

```bash
cd /root/workspace && pulumi up --yes
```{{exec}}

现在看一下这些资源在状态图里的样子：

```bash
pulumi stack export | jq -r '.deployment.resources[] | [.type, (.parent // "—")] | @tsv'
```{{exec}}

你会看到两个 `azure:storage/account:Account` 和那个 `azure:core/resourceGroup:ResourceGroup` 的 `parent` 都是顶层的 `pulumi:pulumi:Stack`——它们是**散装**的，彼此没有共同的父，state 是一张扁平的列表。

这种写法有两个问题：一是想复用这套「主账户 + 日志账户 + 标签」的组合，只能复制粘贴；二是没法把「必须打 managedBy 标签」这样的团队规则固化下来，全靠每个人记得加。下一步我们用组件解决这两个问题。
