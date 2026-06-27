# 完成

你已经完成 AWS / LocalStack RDS 版最佳实践实验。

这次你练习了：

- 用 platform Project 创建共享 PostgreSQL 参数组。
- 用 StackReference 让 workload Project 只读引用上游输出。
- 用 SecurePostgresDatabase 组件封装 RDS 安全默认值。
- 用 Stack Config 和 Secret 组合 orders 与 billing 两个工作负载。
- 用受限输入阻止 dev 环境使用较大规格。
- 用本地 Policy Pack 检查绕开组件的 RDS 资源。

回到正文继续阅读时，可以把同一组概念对应到 Azure 版实验：平台 Stack 输出 Resource Group，工作负载 Stack 创建 PostgreSQL Flexible Server。