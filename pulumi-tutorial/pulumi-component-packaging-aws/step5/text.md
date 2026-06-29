# 检查版本与资源树

先查看 source-based 消费者的状态树。组件和它创建的 S3 Bucket 会显示出父子关系：

```bash
cd /root/workspace/source-consumer && \
pulumi stack export | jq -r '.deployment.resources[] | [.type, (.urn | split("::") | last), (.parent // "—" | split("::") | last)] | @tsv'
```{{exec}}

再对比两个消费者项目的输出：

```bash
cd /root/workspace/native-consumer && \
pulumi stack output && \
cd /root/workspace/source-consumer && \
pulumi stack output
```{{exec}}

这两个项目使用的是同一个组件思想，但分发方式不同。native package 由 npm 安装，source-based package 由 Pulumi 生成 SDK。

官方的 AWS quickstart VPC 仓库可以作为更完整的 component provider 对照。它有公开 tag，例如 `v0.0.5`。

```bash
git ls-remote --tags https://github.com/pulumi/pulumi-aws-quickstart-vpc.git refs/tags/v0.0.5
```{{exec}}

真实项目消费远端 Git 版本时，命令会长得像这样：

```bash
pulumi package add github.com/pulumi/pulumi-aws-quickstart-vpc@v0.0.5
```

下一步会展示第三条路径：安装一个预编译的本地 executable-based plugin，并从这个可执行文件生成消费者 SDK。最后一步结束后，再统一清理三个消费者项目。