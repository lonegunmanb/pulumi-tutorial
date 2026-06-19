# 组件演进：子资源改名与 aliases

组件被多处复用后就成了一份「契约」。演进时，**加东西**通常安全，**改名**却可能触发资源重建。这一步演示后者。

假设我们想把组件里的日志桶改名：逻辑名 `${name}-logs → ${name}-access-logs`。先看「天真」的改法——直接改名、不加 alias：

```bash
cd /root/workspace && cp variants/evolve-broken.ts index.ts && pulumi preview
```{{exec}}

注意 preview 的计划：它不是温和的 update，而是 **delete 旧桶、create 新桶（`-logs → -access-logs`）**。原因正是上一章那条规则——子资源的 URN 包含父组件的类型和名字，改了子资源的 logical name 就改了 URN，Pulumi 把它当成两个不相关的资源。在组件内部改名，一样会触发替换。

现在换成「正确」的改法——改名的同时加 `aliases`，认领旧子资源：

```bash
cp variants/evolve-fixed.ts index.ts && diff variants/evolve-broken.ts variants/evolve-fixed.ts
```{{exec}}

唯一的区别就是日志桶多了一个 `aliases` 选项，认领旧名 `${name}-logs`。再看 preview：

```bash
pulumi preview
```{{exec}}

这次不再有 delete + create，而是把 state 里那条 `-logs → -access-logs` 的记录**就地改名**，云上的桶原地保留。应用它：

```bash
pulumi up --yes && \
pulumi stack export | jq -r '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | .urn | split("::") | last'
```{{exec}}

四个桶里现在是 `media-access-logs / backups-access-logs`，但它们和改名前是**同一批**云资源——没有任何重建。

这就是组件演进的核心心法：**加可选入参、加子资源、加输出都安全；改类型名或子资源 logical name 会触发重建，必须用 `aliases` 兜住。** 对外发布、被他人复用的组件，这类 alias 往往要长期保留。
