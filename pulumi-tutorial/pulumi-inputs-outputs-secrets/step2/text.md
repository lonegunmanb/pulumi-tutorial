# 创建 Secret 输出

把 `index.ts` 中的 `message` 输出改成：

```ts
export const message = pulumi.secret(pulumi.interpolate`Hello from ${pet.id}`);
```

然后运行：

```bash
pulumi up --yes && \
pulumi stack output && \
pulumi stack export | jq '.deployment.resources[] | select(.outputs) | .outputs'
```{{exec}}

观察 Secret 在状态中的加密表现。