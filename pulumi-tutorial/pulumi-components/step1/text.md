# 平铺资源：没有层级

先启动 MiniStack（本地 AWS 模拟器），确认健康后部署初始程序：

```bash
cd /root/workspace && \
docker compose up -d && \
curl -s http://localhost:4566/_ministack/health | jq . && \
pulumi up --yes
```{{exec}}

看一眼初始程序声明了什么：

```bash
cat /root/workspace/index.ts
```{{exec}}

它在 `index.ts` 里**平铺**地声明了两个 S3 Bucket：`media-logs`（访问日志桶）和 `media-bucket`（主桶）。这是没有组件时的常见写法——每个资源各写一遍、各设一遍 `provider`、各打一遍标签。

现在看一下这两个资源在状态图里的样子：

```bash
pulumi stack export | jq -r '.deployment.resources[] | [.type, (.parent // "—")] | @tsv'
```{{exec}}

你会看到两个 `aws:s3/bucket:Bucket` 的 `parent` 都是顶层的 `pulumi:pulumi:Stack`——它们是**散装**的，彼此没有共同的父，state 是一张扁平的列表。

这种写法有两个问题：一是想复用这套「主桶 + 日志桶 + 标签」的组合，只能复制粘贴；二是没法把「必须打 managedBy 标签」这样的团队规则固化下来，全靠每个人记得加。下一步我们用组件解决这两个问题。
