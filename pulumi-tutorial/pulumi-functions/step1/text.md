# Provider functions：direct 与 output form

**Provider function** 用来向云 API 查询一个「不是资源」的值。本步用 `aws.getCallerIdentity`（查询当前调用者身份，会命中 MiniStack 的 STS）对比它的两种形态。

先看程序写了什么：

```bash
cd /root/workspace && cat variants/step1.ts
```{{exec}}

要点：

- `aws.getCallerIdentityOutput({})` 是 **output form**：返回 `Output`，能参与依赖图、能直接接住别的 `Output`。
- `aws.getCallerIdentity({})` 是 **direct form**：返回 `Promise`，`await` 后拿到普通值——适合用在「函数结果决定某资源是否创建」这类必须提前算出来的分支里。

把它复制为入口程序并部署：

```bash
cp variants/step1.ts index.ts && pulumi up --yes
```{{exec}}

> 若提示 `Enter your passphrase`，直接按回车（空口令）。也可先执行 `export PULUMI_CONFIG_PASSPHRASE=""`{{exec}} 让当前终端记住。

查看两种形态返回的值：

```bash
pulumi stack output
```{{exec}}

你会看到 `accountIdOutputForm` 与 `accountIdDirectForm` 都是 `000000000000`（MiniStack 默认账号），`callerArn` 是一个 STS ARN。两种形态拿到的数据相同，区别只在**何时执行**与**返回类型**：

- output form 被引擎追踪、等输入 resolve 后才执行，返回 `Output`。
- direct form 像普通函数调用一样立即执行，返回 `Promise`，不进依赖图。

> Pulumi 的官方建议：没有特殊理由时**默认用 output form**，全程只用一套 Input/Output 模型。
