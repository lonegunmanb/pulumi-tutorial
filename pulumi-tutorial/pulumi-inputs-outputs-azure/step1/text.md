# Output 为什么不能当普通值用

环境初始化时已经启动 miniblue（本地 Azure 模拟器）并把它的 metadata 证书加入了系统信任库，可以直接开始。

先看一眼初始程序：

```bash
cat /root/workspace/index.ts
```{{exec}}

部署初始程序：

```bash
cd /root/workspace && pulumi up --yes
```{{exec}}

`index.ts` 里只建了一个 Resource Group，但故意用两种方式打印它的 id：

- `console.log("直接打印 rg.id ...", dataRg.id)` —— 直接把 Output 当值用；
- `dataRg.id.apply(id => console.log(...))` —— 用 `apply` 等真实值。

回看刚才 `pulumi up` 的输出，对照两行日志：

- 直接打印那行，看到的**不是**真实 id，而是一个 Output 对象（或一条「不能对 Output 调用 toString」的警告）——因为执行 `console.log` 那一刻，Resource Group 还没建好，id 这个值根本还不存在。
- `apply` 那行打印出了真实的 ARM resource ID——因为它等到值就绪后才运行回调。

再看导出的 stack output：

```bash
pulumi stack output
```{{exec}}

`rgId` / `rgName` 都是资源创建后才确定的值。记住一句话：**你在代码里拿到的往往不是值本身，而是装着未来之值的盒子（Output）。**
