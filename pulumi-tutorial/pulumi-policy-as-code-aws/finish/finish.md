# 完成

你已经完成 AWS 版 Policy as Code 实验。

这次你练习了：

- 编写本地 TypeScript Policy Pack。
- 用 mandatory 策略阻断缺失标签的 S3 Bucket。
- 用 advisory 策略提示命名规范。
- 在 preview 和 up 阶段使用同一个策略包。
- 了解本地策略包与 Pulumi Cloud Policy Groups 的边界。

生产环境中，建议把策略包加入 CI，并为关键规则补充单元测试。