# 复用组件与 providers 继承

组件最大的价值是**复用**。切换到把同一个组件实例化两次的版本：

```bash
cd /root/workspace && cp variants/reuse.ts index.ts && cat index.ts
```{{exec}}

这份代码只多了一行：除了 `media`，又实例化了一个 `backups`。组件定义本身一个字没改。部署它：

```bash
pulumi up --yes
```{{exec}}

现在 state 里有两棵子树。看看四个桶的逻辑名：

```bash
pulumi stack export | jq -r '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | .urn | split("::") | last'
```{{exec}}

你会看到 `media-bucket`、`media-logs`、`backups-bucket`、`backups-logs`——子资源名各自带上了实例名前缀，互不冲突。这正是「子资源名必须用 `${name}` 拼前缀」的意义：如果当初把日志桶硬编码成 `"logs"`，两个实例就会撞 URN 而报错。

再验证一下 **providers 继承**。子资源代码里并没有写 `provider`，它们怎么连上 MiniStack 的？答案是：provider 通过组件实例的 `providers: [localAws]` 下传，再经子资源的 `parent: this` 继承下来。确认所有桶用的都是同一个显式 provider：

```bash
pulumi stack export | jq -r '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | [( .urn | split("::") | last), (.provider // "default")] | @tsv'
```{{exec}}

每个桶的 `provider` 字段都指向名为 `ministack` 的 provider，而不是 default。这就是为什么组件要用 `providers`（复数）而不是 `provider`（单数）：组件自己不调云 API，把 provider 配置下发给子资源才有意义。
