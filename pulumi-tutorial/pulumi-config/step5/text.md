# 一套程序，多个 Stack

配置系统的终极用途：**同一套程序，不同 Stack 各用一份配置，产出不同的基础设施**。这一步继续使用 TypeScript，并且沿用前面已经看到的窄导入方式，只加载 S3 与 Provider 相关模块，避免把整个 AWS SDK 入口一次性载入 Node 进程。

先切换到这一步的程序，看看它如何读取配置：

```bash
cd /root/workspace && cp variants/step5.ts index.ts && cat index.ts
```{{exec}}

程序从配置读取 bucketPrefix、bucketCount，再多读一个 owner。我们不在 dev 上设置 owner，而是把它作为**项目级默认值**写在项目文件里，供所有 Stack 共享：

```bash
cat Pulumi.yaml
```{{exec}}

项目级默认值不能用 pulumi config set 设置；这个命令只写 Stack 配置。项目级默认值要直接写在 Pulumi.yaml 的 config 块里。

准备 dev Stack 的配置。它不设置 owner，因此会读到项目级默认值：

```bash
pulumi stack select dev && \
pulumi config set bucketPrefix dev && \
pulumi config set bucketCount 3
```{{exec}}

部署 dev。这里给 Node 设置一个保守的堆上限，作为防止宽导入回归的保险丝：

```bash
NODE_OPTIONS=--max-old-space-size=512 pulumi up --yes --non-interactive && pulumi stack output
```{{exec}}

现在切换到 prod Stack，给它一份**完全不同**的配置：

```bash
pulumi stack select prod || pulumi stack init prod
```{{exec}}

```bash
pulumi config set bucketPrefix prod && \
pulumi config set bucketCount 4 && \
pulumi config set aws:region us-west-2 && \
pulumi config set owner prod-team
```{{exec}}

其中 owner 这一行**覆盖**了项目级默认值。部署 prod：

```bash
NODE_OPTIONS=--max-old-space-size=512 pulumi up --yes --non-interactive && pulumi stack output
```{{exec}}

最后对比两个 Stack 的产出——同一套程序，规模与归属却各不相同：

```bash
echo '--- dev ---' && pulumi stack output --stack dev bucketNames && \
echo '--- prod ---' && pulumi stack output --stack prod bucketNames
```{{exec}}

dev 是 3 个 dev-bucket-*、owner 为 platform-team；prod 是 4 个 prod-bucket-*、owner 为 prod-team。程序一行没改，差异全在配置里。这正是「一套程序、多个 Stack」的标准工作方式。
