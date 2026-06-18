# Dynamic Provider：亲手写 CRUD

当一个东西**既没有 Pulumi 包、也没有 Terraform provider**，但逻辑很简单时，你可以在程序里内联实现一个 **dynamic provider**——亲手写 `create`/`update`/`delete`。这是理解 provider 抽象最直观的方式：你就是那个「翻译官」。

切到 dynamic provider 版本并创建资源。先看看 `step3.ts` 写了什么：

```bash
cd /root/workspace && cat variants/step3.ts
```{{exec}}

它实现了一个 `pulumi.dynamic.ResourceProvider`——`create` 把 `message` 转成大写存进 `shout`、把 `version` 置 1，`update` 在改动时把 `version` 自增，`delete` 负责清理；再用这个 provider 定义了一个 `Greeting` 资源。理解了这段逻辑，下面的输出就都能对上号了。现在部署：

```bash
cp variants/step3.ts index.ts && pulumi up --yes
```{{exec}}

`step3.ts` 实现了一个 `pulumi.dynamic.ResourceProvider`，并用它定义了一个 `Greeting` 资源。这次 `pulumi up` 显示 `+ 1 created`——引擎调用了你写的 **create**。看看它返回的输出：

```bash
pulumi stack output
```{{exec}}

`shout` 是 create 里算出来的（把 message 转大写），`version` 是 1。

现在**只改 message**，再部署一次，观察引擎调用的是 **update** 而不是 replace：

```bash
cp variants/step3-update.ts index.ts && pulumi up --yes
```{{exec}}

这次摘要是 `~ 1 updated`（不是 `+-` 替换）。再看输出：

```bash
pulumi stack output
```{{exec}}

`shout` 变成了新 message 的大写，`version` 自增到 2——这正是你在 **update** 方法里写的逻辑。

最后销毁，观察引擎调用 **delete**：

```bash
pulumi destroy --yes
```{{exec}}

摘要是 `- 1 deleted`，引擎调用了你写的 **delete**。

要点：

- 你写的 `create`/`update`/`delete` 就是 provider 进程要执行的 CRUD——dynamic provider 把「翻译官」角色直接交到你手里。
- 引擎调用它们的时机（先 check/diff，再决定 create / update / replace / delete）与标准 provider 完全一致。
- 限制：只能被同语言程序使用、不支持 `read`（故不能 `pulumi import`）、方法受函数序列化限制、仅 TS/Python。
- 动手写 dynamic provider 前先自问：现成 provider、Any Terraform Provider、Command provider 是不是已经够用？它常常不是最佳解。
