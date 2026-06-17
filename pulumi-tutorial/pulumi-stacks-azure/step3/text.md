# 部署 dev 并查看 Stack

先切回 `dev`，用 `preview` 看计划，再用 `up` 执行。这里你会看到资源名里包含 `dev`，因为程序读取了当前 Stack 名。

```bash
cd /root/workspace/azure-stacks && \
source venv/bin/activate && \
pulumi stack select dev && \
pulumi preview && \
pulumi up --yes
```{{exec}}

部署完成后查看当前 Stack 的资源、输出和元数据：

```bash
pulumi stack && \
pulumi stack output && \
pulumi stack output --json | jq .
```{{exec}}

这一步要理解三件事：

- `pulumi stack` 显示当前 Stack 的资源和 Outputs。
- `pulumi stack output` 读取这个 Stack 对外暴露的值。
- `adminPasswordPreview` 默认显示为 `[secret]`，因为它来自 Secret 配置。

如果你只想查看某个输出，可以直接指定名称：

```bash
pulumi stack output resource_group && \
pulumi stack output qualified_stack
```{{exec}}

`qualified_stack` 展示了本地后端里的完整引用格式：`organization/<project>/<stack>`。