# 修改期望状态

这一步展示 Pulumi 的核心特性：**当代码改变时，Pulumi 能聪明地判断需要什么改动**。我们只改一个标签，看 Pulumi 会做什么。

修改程序代码中的一个标签值：

```bash
cd /root/workspace && \
sed -i 's/stage: "first-up"/stage: "updated-in-place"/' index.ts && \
pulumi preview
```{{exec}}

观察 preview 的输出：注意这次的操作是 `~` 符号（表示"修改"），而不是 `+` 符号（表示"创建"）。这是因为 Pulumi 通过对比新代码和旧 State，发现这个 S3 Bucket 已经存在，只需要更新它的标签。

确认预览后执行更新：

```bash
pulumi up --yes
```{{exec}}

查询更新后的标签，确认改动已经生效：

```bash
pulumi stack export | jq -r '.deployment.resources[] | select(.type=="aws:s3/bucket:Bucket") | .outputs.tags'
```{{exec}}

核心概念：
- **`+` 符号**（create）：资源不存在，需要新建。
- **`~` 符号**（update）：资源已存在，但属性有改动，需要更新。
- **`-` 符号**（delete）：代码中删除了资源声明，需要销毁。
- 每次运行 Pulumi 时，它都会重新执行你的程序代码，拿最新的"图纸"和旧 State 比较，然后只执行必要的改动——这就是所谓的"声明式基础设施"。