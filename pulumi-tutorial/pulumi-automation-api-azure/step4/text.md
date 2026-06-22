# 包装成 HTTP 接口

想象团队有一个 Internal Developer Platform：开发者在网页上为某个服务申请一套临时基础设施，平台后端负责调用 Pulumi，而不是让开发者登录服务器执行脚本。这里我们用 Node.js 内置 HTTP 模块创建一个很薄的服务，模拟这个平台后端。

这个服务提供的核心路径是 `/stacks/svc1`。路径末尾的 svc1 是 Stack 名，代表内部平台里的一个示例服务环境；HTTP 方法和后缀路径决定要执行预览、更新、读取输出还是销毁。

```bash
cd /root/workspace && \
(nohup npx ts-node --transpile-only server.ts >/tmp/automation-api-server.log 2>&1 & echo $! > /tmp/automation-api-server.pid) && \
sleep 2 && \
curl -s -X POST http://localhost:3000/stacks/svc1/preview | jq
```{{exec}}

这个请求会为名为 svc1 的服务 Stack 生成预览，但不会创建资源。真实平台还需要补上身份校验、参数校验、并发控制和审计记录。

现在通过同一个 HTTP 接口创建这个服务 Stack，并读取输出：

```bash
cd /root/workspace && \
curl -s -X POST http://localhost:3000/stacks/svc1 | jq && \
curl -s http://localhost:3000/stacks/svc1/outputs | jq
```{{exec}}