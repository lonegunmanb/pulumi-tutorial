# 用 all 组合多个 Output

要**同时**用到多个 Output 时，用 `all`：等所有 Output 都就绪后，把它们作为一组普通值交给回调。`all` 的返回值同样是 Output。

先看代码：

```bash
cat /root/workspace/variants/step4.ts
```{{exec}}

部署：

```bash
cd /root/workspace && cp variants/step4.ts index.ts && pulumi up --yes
```{{exec}}

`step4.ts` 用 `all` 做了两件事：

- `summary`：把两个桶的名字拼成一条字符串；
- `inventory`：把两个桶的 arn 组合成一个对象。

看结果：

```bash
pulumi stack output
```{{exec}}

`pulumi.all([...])` 接受一组 Output，等它们全部就绪后一次性交给 `apply` 回调——这是「跨多个资源取值」的标准做法。`apply` 适合处理单个 Output，`all` 则负责把多个 Output 汇聚到一起。
