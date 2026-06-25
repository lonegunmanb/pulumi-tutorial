# Pulumi 调试与故障排查（AWS / MiniStack）

本实验使用 MiniStack 提供本地 AWS S3 风格 API，不需要真实 AWS 账号，也不需要 Pulumi Cloud 账号。

你将在 /root/workspace/debugging-aws 中操作一个 TypeScript Pulumi Project。程序会声明一个 S3 Bucket，并故意保留几个可触发的排障点。

实验会覆盖四类动作：定位缺失 Stack 配置、查看程序日志、打开 Provider 详细日志、用 refresh 识别控制台外改动。