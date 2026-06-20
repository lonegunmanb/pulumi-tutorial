# Stash 状态暂存（纯本地）

本实验使用本地 Pulumi 后端和一个 TypeScript 项目。项目只安装 Pulumi SDK，不需要 AWS、Azure 或 Kubernetes provider。

你会看到同一个 Stash 的当前输入如何变化，而保存值如何在 state 中保持稳定。后半部分还会演示复杂对象、secret 和删除行为。