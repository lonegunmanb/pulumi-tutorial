# 完成

你已经完成 Azure 版 Policy as Code 实验。

这次你练习了：

- 编写本地 TypeScript Policy Pack。
- 用 mandatory 策略阻断错误区域和缺失标签。
- 用 advisory 策略提示命名前缀。
- 在 preview 和 up 阶段使用同一个策略包。
- 理解本地策略包与 Pulumi Cloud Policy Groups 的边界。

生产环境中，建议把区域、标签和命名规则放进版本化策略包，并在 CI 中强制执行。