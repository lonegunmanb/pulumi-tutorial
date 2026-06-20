# 一套程序，多个 Stack（改用 Go 演示）

配置系统的终极用途：**同一套程序，不同 Stack 各用一份配置，产出不同的基础设施**。这个理念与编程语言无关。前面几步用的是 TypeScript，这一步我们换用 **Go** 演示同样的概念——Go 程序的语言宿主进程内存占用要低得多，在内存受限的实验机上连续部署多个 Stack 更稳。

> 一个 Pulumi 项目的 runtime 是固定的，无法在同一目录里混用语言。所以 Go 版放在独立目录 `/root/workspace-go`，前后步骤的 TypeScript 项目仍在 /root/workspace。

先进入 Go 项目目录，看看这段程序：

```bash
cd /root/workspace-go && cat main.go
```{{exec}}

它和前面的 TS 程序逻辑一致：从配置读取 bucketPrefix、bucketCount，再多读一个 owner。我们不在某个 Stack 上设 owner，而是把它设成**项目级默认值**——所有 Stack 共享。项目级默认值不能用 pulumi config set 设置（那只写 Stack 级配置），只能直接写在 Pulumi.yaml 的 config 块里，这里已经预置好：

```bash
cat Pulumi.yaml
```{{exec}}

dev Stack 已经预置好（bucketPrefix=dev、bucketCount=3），但它的配置里从没设过 owner。部署它，却能读到 `platform-team`——这就是项目级默认值在起作用：

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

其中 owner 这一行**覆盖**了项目级默认值。部署 `prod`：

```bash
pulumi up --yes && pulumi stack output
```{{exec}}

最后对比两个 Stack 的产出——同一套程序，规模与归属却各不相同：

```bash
echo '--- dev ---' && pulumi stack output --stack dev bucketNames && \
echo '--- prod ---' && pulumi stack output --stack prod bucketNames
```{{exec}}

dev 是 3 个 dev-bucket-*、owner 为 platform-team；prod 是 4 个 prod-bucket-*、owner 为 prod-team。程序一行没改，差异全在配置里。这正是「一套程序、多个 Stack」的标准工作方式——无论用 TypeScript 还是 Go。
