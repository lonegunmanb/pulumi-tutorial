# 修复程序让测试通过

现在只做最小修改：给 S3 Bucket 补齐 owner 与 managedBy 标签。

```bash
cd /root/workspace && \
cat asserts/fixed-index.ts && \
cp asserts/fixed-index.ts index.ts
```{{exec}}

重新运行单元测试。绿色结果说明资源输入已经满足测试写下的约束。

```bash
cd /root/workspace && \
npm run test:unit
```{{exec}}

再看一次 preview。单元测试不需要 Pulumi CLI，但 preview 会执行真实 Pulumi 入口，并通过 AWS provider 对接 MiniStack。

```bash
cd /root/workspace && \
pulumi stack select dev && \
pulumi preview
```{{exec}}