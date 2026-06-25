# 用 refresh 识别漂移

现在模拟一次控制台外改动。我们不用 Pulumi，而是直接调用 miniblue API 修改 Resource Group 标签。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
RG=$(pulumi stack output resourceGroupName) && \
curl -s -X PUT "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" -H 'Content-Type: application/json' -d '{"location":"eastus","tags":{"owner":"console-change","environment":"dev","diagnostic":"manual","managedBy":"manual"}}' | jq .tags
```{{exec}}

普通 preview 只比较程序和 State。它通常不会主动读取真实资源，所以这一步未必能发现刚才的手工改动。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi preview --diff
```{{exec}}

现在先预览 refresh。它会从 miniblue 读取真实资源，并显示 State 将如何变化。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi refresh --preview-only --diff
```{{exec}}

确认后执行 refresh，再用 up 把真实标签恢复到代码声明。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi refresh --yes && \
pulumi preview --diff && \
pulumi up --yes --diff && \
RG=$(pulumi stack output resourceGroupName) && \
curl -s "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" | jq .tags
```{{exec}}

顺序很关键：refresh 更新 State 对真实资源的认识，preview 再判断是否需要回到程序声明。