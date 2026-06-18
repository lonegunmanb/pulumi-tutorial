# Output 为什么不能当普通值用

先启动 MiniStack（本地 AWS 模拟器），确认健康后部署初始程序：

```bash
cd /root/workspace && \
docker compose up -d && \
curl -s http://localhost:4566/_ministack/health | jq . && \
pulumi up --yes
```{{exec}}

再看一眼初始程序：

```bash
cat /root/workspace/index.ts
```{{exec}}

`index.ts` 里只建了一个 S3 Bucket，但故意用两种方式打印它的 id：

- `console.log("直接打印 bucket.id ...", dataBucket.id)` —— 直接把 Output 当值用；
- `dataBucket.id.apply(id => console.log(...))` —— 用 `apply` 等真实值。

回看刚才 `pulumi up` 的输出，对照两行日志：

- 直接打印那行，看到的**不是**真实 id，而是一个 Output 对象（或一条「不能对 Output 调用 toString」的警告）——因为这行代码执行时，Bucket 还没建好，id 这个值根本还不存在。
- `apply` 那行打印出了真实的 bucket 名——因为它等到值就绪后才运行回调。

再看导出的 stack output：

```bash
pulumi stack output
```{{exec}}

`bucketId` / `bucketName` / `bucketArn` 都是资源创建后才确定的值。记住一句话：**你在代码里拿到的往往不是值本身，而是装着未来之值的盒子（Output）。**
