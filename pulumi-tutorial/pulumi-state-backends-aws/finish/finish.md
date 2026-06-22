# 完成

你已经完成 AWS 版 State 与 Backend 实验。

这次你练习了：

- 使用 S3 DIY Backend 保存 Pulumi State。
- 通过 pulumi login 选择 Backend。
- 用项目文件中的 backend.url 固定 Backend 地址。
- 创建 dev 与 prod 两个独立 Stack。
- 观察 DIY Backend 中的 .pulumi 目录结构。
- 区分 Backend 凭据与 provider 凭据。
- 使用 pulumi stack export 与 pulumi stack import 处理 State 文件。

在真实团队中，S3 Backend 还需要配套 bucket policy、版本保留、备份策略和访问审计。
