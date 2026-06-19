# Function serialization：把闭包变成 Lambda

这一步是本章的重头戏：把一段 **JavaScript 闭包**直接序列化成 **AWS Lambda**，部署到 MiniStack 的 Node.js 运行时，再真正 `invoke` 它。

先看程序：

```bash
cd /root/workspace && cat variants/step3.ts
```{{exec}}

关键点：回调外部定义的 `greetingPrefix` 和 `builtAt` **被闭包捕获**。`aws.lambda.CallbackFunction` 会替你做完所有脏活——序列化回调与捕获的变量、创建 IAM Role/Policy、打包代码、建出 Lambda。你不用手写 `index.js`，也不用配 Role。

部署（会在 MiniStack 里创建 IAM Role 与 Lambda 函数）：

```bash
cp variants/step3.ts index.ts && pulumi up --yes
```{{exec}}

拿到 Lambda 的函数名：

```bash
pulumi stack output greeterFunctionName
```{{exec}}

现在真正 `invoke` 它。MiniStack 会用官方 Node.js 运行时镜像执行这段序列化后的闭包（第一次调用要拉运行时容器，可能稍慢）：

```bash
FN=$(pulumi stack output greeterFunctionName) && \
awslocal lambda invoke \
  --function-name "$FN" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name":"Pulumi"}' \
  /tmp/out.json >/dev/null && \
cat /tmp/out.json; echo
```{{exec}}

返回的 JSON 里，`message` 是 `Hello from a serialized closure: Pulumi`——`greetingPrefix`（捕获的外部变量）和 `name`（调用时传入的事件）在云端被组合了起来；`builtAt` 则是**序列化那一刻**被定格的时间戳。

要点：

- 捕获的变量在**序列化时求值**并定格——所以**不要捕获会被修改的可变值**。
- 模块（如 `fs`）会被转成运行时的 `require`，而不是整体序列化；`@pulumi/*` 包会被自动剔除。
- 这套机制仅支持 **Node.js（JavaScript/TypeScript）**，且不支持 Bun runtime。
