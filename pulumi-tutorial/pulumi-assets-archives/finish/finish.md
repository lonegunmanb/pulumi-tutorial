# 实验完成

你已经把 Pulumi 的 Assets 与 Archives 跑完了一轮：

- 用 StringAsset、FileAsset、RemoteAsset 创建了三个 S3 Object。
- 用 FileArchive 把本地目录部署成 Lambda 代码包。
- 用 AssetArchive 组合了字符串、文件和目录。
- 用 RemoteArchive 从 file URI 引用了一个 ZIP 包。
- 通过 state export 观察了它们作为资源输入时的大致形态。

清理资源（可选）：

```bash
cd /root/workspace && \
pulumi destroy --yes && \
docker compose down -v
```{{exec}}

回到教程继续阅读下一章时，请记住这条主线：Asset 是单个文件，Archive 是一组文件；它们通常通过某个资源输入进入部署，而不是单独成为资源。