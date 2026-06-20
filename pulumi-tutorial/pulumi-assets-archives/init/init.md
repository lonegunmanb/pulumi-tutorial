# Assets 与 Archives：AWS / MiniStack 版

本实验使用本地 MiniStack 模拟 AWS，不需要真实云账号。你会用 Pulumi 的 Asset 把单个文件上传成 S3 Object，再用 Archive 把一组文件部署成 Lambda 代码包。

实验环境会预先准备好：

- 一个 TypeScript Pulumi 项目。
- 一组本地示例文件和 Lambda 代码目录。
- 一个指向 MiniStack 的 AWS provider。
- 一个可用的 awslocal 命令。

每一步只需要把 variants 目录里的程序复制到入口文件，然后运行 Pulumi 命令。

> 本实验使用空口令的本地后端。若终端提示输入 passphrase，直接按回车即可。