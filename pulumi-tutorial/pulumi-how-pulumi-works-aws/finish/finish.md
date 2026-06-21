# 完成

你已经用 `@pulumi/aws` + MiniStack 跑完了一次完整的 Pulumi 工作流：

- 第一次部署时，空 State 让两个 Bucket 产生 create。
- 部署完成后，State 记录了 URN、物理名、物理 ID 与输出。
- 标签变化被 Provider 判断为可原地 update。
- 逻辑名变化会改变资源身份，预览中表现为 create 加 delete。
- 删除程序里的资源声明后，Engine 会根据 State 安排 delete。

下一章可以继续学习安装与本地后端；进入资源章节后，你会用 aliases、deleteBeforeReplace 等选项更精细地控制这些行为。