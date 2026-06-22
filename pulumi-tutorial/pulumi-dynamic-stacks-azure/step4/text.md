# 用 refresh 发现标签漂移

现在模拟一次控制台外改动。我们直接调用 miniblue，把 prod Resource Group 的标签改掉：

```bash
cd /root/workspace && \
RG=$(pulumi stack output resourceGroupName --stack prod) && \
curl -s -X PUT "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" -H 'Content-Type: application/json' -d '{"location":"eastus","tags":{"owner":"portal-change","environment":"prod","managedBy":"manual"}}' | jq .
```{{exec}}

真实资源已经偏离代码声明。先运行 refresh，让 State 读取当前真实资源状态：

```bash
pulumi refresh --yes --stack prod
```{{exec}}

完整 refresh 会让当前 Stack 里所有已托管资源都重新从模拟器读取一次。接着运行 preview。它会显示为了回到配置声明，需要把标签改回去：

```bash
pulumi preview --stack prod
```{{exec}}

确认后执行修复，并再次查询真实标签：

```bash
pulumi up --yes --stack prod && \
RG=$(pulumi stack output resourceGroupName --stack prod) && \
curl -s "http://localhost:4566/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/$RG" | jq .tags
```{{exec}}

这一步的重点是顺序：refresh 先更新 State 对真实世界的认识，preview 再告诉你代码目标状态和真实世界之间的差异。
