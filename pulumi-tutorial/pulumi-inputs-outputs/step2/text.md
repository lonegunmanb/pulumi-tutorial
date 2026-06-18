# 用 apply 变换单个 Output

`apply` 用来访问**单个** Output 的真实值并对它做运算，返回的**仍是一个 Output**（依赖关系自动继承）。

先看代码：

```bash
cat /root/workspace/variants/step2.ts
```{{exec}}

部署：

```bash
cd /root/workspace && cp variants/step2.ts index.ts && pulumi up --yes
```{{exec}}

`step2.ts` 用 `apply` 做了两次变换：

- `arnUpper`：把 `dataBucket.arn` 转成大写；
- `bucketEndpoint`：把 bucket 名拼成一个伪 endpoint URL。

看结果：

```bash
pulumi stack output
```{{exec}}

`bucketArnUpper` 是基于 `bucketArn` 变换出来的**新 Output**——它会等原 Output 就绪、跑完回调，再把结果暴露出来，全程保留对 `data-bucket` 的依赖。

> 关于 **lifting（提升）**：如果某个 Output 本身是对象或数组，你可以直接在它上面访问属性 / 下标（例如 `cert.domainValidationOptions[0].resourceRecordName`），无需显式 `apply`，Pulumi 会自动把访问提升到 Output 上下文。只是当某个值可能为 `undefined` 时，仍需回退到 `apply` 并自行做空值检查。
