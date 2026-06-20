# 实验完成

你已经完成 Stash 的核心流程：

- 创建 Stash，并看到第一次部署时当前输入与保存值相同。
- 修改当前输入，并确认保存值默认保持不变。
- 使用定向替换刷新保存值。
- 保存复杂对象，并验证 secret 会被遮蔽。
- 从程序中移除 Stash，并让 Pulumi 从 state 删除它。

清理本地 Stack（可选）：

```bash
cd /root/workspace && \
pulumi destroy --yes --non-interactive
```{{exec}}

回到正文时，请把 Stash 记成一句话：它适合把部署时计算出的首次值保存到 Stack state，而不是替代 Config 或业务数据库。