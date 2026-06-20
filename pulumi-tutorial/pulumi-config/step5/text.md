# 一套程序，多个 Stack

配置系统的终极用途：**同一套程序，不同 Stack 各用一份配置，产出不同的基础设施**。先切到这一步的完整程序：

```bash
cp variants/step5.ts index.ts && cat index.ts
```{{exec}}

它多读了一个 `owner`。我们不在某个 Stack 上设它，而是把它设成**项目级默认值**——所有 Stack 共享。注意：`pulumi config set` 不支持项目级配置，必须直接编辑 `Pulumi.yaml`：

```bash
cat >> Pulumi.yaml <<'YAML'
config:
  owner: platform-team
YAML
cat Pulumi.yaml
```{{exec}}

先部署 `dev`。它的配置里从没设过 `owner`，却能读到 `platform-team`——这就是项目级默认值在起作用：

```bash
pulumi stack select dev && pulumi up --yes && pulumi stack output
```{{exec}}

现在新建一个 `prod` Stack，给它一份**完全不同**的配置：

```bash
pulumi stack init prod
```{{exec}}

```bash
pulumi config set bucketPrefix prod && \
pulumi config set bucketCount 4 && \
pulumi config set aws:region us-west-2 && \
pulumi config set owner prod-team
```{{exec}}

其中 `owner` 这一行**覆盖**了项目级默认值。部署 `prod`：

```bash
pulumi up --yes && pulumi stack output
```{{exec}}

最后对比两个 Stack 的产出——同一套程序，规模与归属却各不相同：

```bash
echo '--- dev ---' && pulumi stack output --stack dev bucketNames && \
echo '--- prod ---' && pulumi stack output --stack prod bucketNames
```{{exec}}

`dev` 是 3 个 `demo-bucket-*`、owner 为 platform-team；`prod` 是 4 个 `prod-bucket-*`、owner 为 prod-team。程序一行没改，差异全在配置里。这正是「一套程序、多个 Stack」的标准工作方式。
