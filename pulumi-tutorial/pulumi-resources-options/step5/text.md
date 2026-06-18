# protect 与 ignoreChanges

最后两个生产常用选项：`protect` 防误删，`ignoreChanges` 容忍带外漂移。然后清理环境。

**1) 用 `protect: true` 给关键资源上锁**：

先看这一步要运行的代码：

```bash
cat /root/workspace/variants/step5.ts
```{{exec}}

再应用它：

```bash
cd /root/workspace && cp variants/step5.ts index.ts && pulumi up --yes
```{{exec}}

`step5.ts` 给 `data-bucket` 加了 `protect: true`。现在尝试销毁，会被拦截：

```bash
pulumi destroy --yes
```{{exec}}

你会看到类似 `resource ... is protected and can't be deleted` 的报错——这正是 `protect` 在生产里防止误删数据库、状态桶的价值。

**2) 用 `ignoreChanges` 忽略 tag 漂移，并解除保护以便清理**：

先看改动后的代码：

```bash
cat /root/workspace/variants/step5-clean.ts
```{{exec}}

再应用它：

```bash
cp variants/step5-clean.ts index.ts && pulumi up --yes
```{{exec}}

`step5-clean.ts` 做了两件事：

- 给 `assets-bucket` 加了 `ignoreChanges: ["tags"]` 并改了 tag——尽管代码里 tag 变了，预览/应用都**不会**产生 diff，模拟「容忍运维手动改过的字段」。
- 去掉了 `data-bucket` 的 `protect`，让它重新可删除。

**3) 现在可以正常销毁并关停 MiniStack**：

```bash
pulumi destroy --yes && \
docker compose down
```{{exec}}

回顾本实验覆盖的资源选项：`deleteBeforeReplace`、`replaceOnChanges`、`dependsOn`、`aliases`、`protect`、`ignoreChanges`——它们共同构成了在生产环境安全演进基础设施的工具箱。
