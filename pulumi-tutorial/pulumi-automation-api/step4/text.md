# 包装成 HTTP 接口

平台后端通常不会让调用者直接运行脚本，而是提供服务接口。这里用 Node.js 内置 HTTP 模块启动一个很薄的包装层。

```bash
cd /root/workspace && \
(nohup npx ts-node --transpile-only server.ts >/tmp/automation-api-server.log 2>&1 & echo $! > /tmp/automation-api-server.pid) && \
sleep 2 && \
curl -s -X POST http://localhost:3000/environments/review/preview | jq
```{{exec}}

这个请求会为 review Stack 生成预览，但不会创建资源。真实平台还需要补上身份校验、参数校验、并发控制和审计记录。

现在通过同一个 HTTP 接口创建 review 环境，并读取输出：

```bash
cd /root/workspace && \
curl -s -X POST http://localhost:3000/environments/review | jq && \
curl -s http://localhost:3000/environments/review/outputs | jq
```{{exec}}