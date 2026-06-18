# 完成

你已经用 `@pulumi/azure` + miniblue 把 Input/Output 的数据流完整跑通：

- 看清了 Output 不是普通值，必须用 `apply` 取真实值；
- 用 `apply` 变换单个 Output，结果仍是 Output、依赖自动继承；
- 把一个资源的 Output 当作另一个资源的 Input，由此自动建立依赖图与创建顺序，并对比了显式 `dependsOn`；
- 用 `all` 把多个 Output 组合成字符串与对象；
- 用 `interpolate` / `concat` 拼字符串、用 `jsonStringify` 生成 JSON；
- 记住了那条生产红线：不要在 `apply` / `all` 回调里创建资源。

可选清理（释放本地资源）：

```bash
cd /root/workspace && pulumi destroy --yes && docker compose down
```

下一章进入 Components，你会把这些资源与数据流封装成可复用的高层抽象。
