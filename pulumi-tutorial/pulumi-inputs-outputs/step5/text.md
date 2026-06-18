# Output Helpers：拼字符串与生成 JSON

「拼字符串」「生成 JSON」是两类最高频的操作，Pulumi 为它们准备了 helper：内部仍是 `apply` / `all`，但写法更贴近原生。

先看代码：

```bash
cat /root/workspace/variants/step5.ts
```{{exec}}

部署：

```bash
cd /root/workspace && cp variants/step5.ts index.ts && pulumi up --yes
```{{exec}}

看结果：

```bash
pulumi stack output
```{{exec}}

对照三个输出：

- `s3UrlConcat`：用 `pulumi.concat(...)` 把字符串与 Output 依次拼接；
- `s3UrlInterp`：用 `pulumi.interpolate` 模板字面量，`${}` 里直接写 Output——最贴近原生写法；
- `policyJson`：用 `pulumi.jsonStringify({...})` 把含 Output 的结构整体序列化成 JSON 字符串，其中 `Resource` 用 `interpolate` 在 ARN 后追加了 `/*`。

> **重要陷阱：不要在 `apply` / `all` 回调里创建资源。** 下面是反面写法（仅作演示，不要运行）：
>
> ```ts
> // ❌ 反模式：在 apply 回调里 new 资源
> dataBucket.arn.apply(arn =>
>   new aws.s3.BucketObject("bad", { bucket: dataBucket.id, key: arn }, { provider: localAws }),
> );
> ```
>
> 这样创建的资源在 `pulumi preview` 里往往不显示，导致「预览的计划」与「实际执行」不一致。正确做法是把依赖的 Output **直接当 Input 传给资源**，让 Pulumi 自行追踪依赖。
