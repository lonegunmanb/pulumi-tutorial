# default 与 explicit provider

先看一个资源在**没有显式 provider** 时是怎么跑起来的。初始程序 `index.ts` 用 `@pulumi/random` 创建了一个 `RandomPet`，没有设置 `{ provider }`，因此用的是 **default provider**：

```bash
cd /root/workspace && pulumi up --yes
```{{exec}}

部署成功后，看看 Pulumi 为此自动下载并使用了哪个 provider 插件：

```bash
pulumi plugin ls
```{{exec}}

你会看到一个 `random` 资源插件——这就是 4.2 里那个 `pulumi-resource-random` 可执行文件，真正执行「生成随机名字」的就是它，而不是你的 `index.ts`。

现在切换到 **explicit provider** 版本：它把 provider 自己 `new` 出来当成一个资源，再用 `{ provider }` 挂到资源上。

```bash
cp variants/step1-explicit.ts index.ts && pulumi up --yes
```{{exec}}

观察 state 里现在多了一个 provider 资源：

```bash
pulumi stack export | jq -r '.deployment.resources[] | select(.type | test("pulumi:providers:")) | .urn'
```{{exec}}

要点：

- **default provider** 从不在代码里声明，配置走系统环境或 `pulumi config set <provider>:<key>`。最省事。
- **explicit provider** 本身就是一个资源（注意 state 里出现的 `pulumi:providers:random`），配置在声明时传入，且参数可以是 Pulumi Input/Output。
- 这里 random 没有有意义的配置，所以两种方式效果相同；但用法与上一章 `new aws.Provider("ministack", {...})` 完全一致——多区域、多集群、指向测试替身等场景**必须**用 explicit provider。
