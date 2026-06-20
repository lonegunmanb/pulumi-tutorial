# 组件配置：组件读取自己命名空间的配置

前面所有配置键都属于**项目自己的命名空间**（在本实验里就是 `pulumi-config:`）。但当你把一组资源封装成可复用的 **Component** 时，更好的做法是：让组件从**它自己的命名空间**读配置，与宿主项目互不干扰。

先回到本项目和它的 `dev` Stack：

```bash
cd /root/workspace && pulumi stack select dev
```{{exec}}

换上这一步的程序。它定义了一个 BucketFleet 组件，组件内部用 `new pulumi.Config("app")` 只读取 app: 前缀的键：

```bash
cp variants/step6.ts index.ts && cat index.ts
```{{exec}}

现在为组件设置它自己命名空间下的配置。注意键名前缀是 `app:`，而不是项目名：

```bash
pulumi config set app:bucketPrefix fleet
```{{exec}}

```bash
pulumi config set app:bucketCount 3
```{{exec}}

部署。组件会按 `app:bucketCount` 创建 3 个以 fleet 为前缀的 Bucket：

```bash
pulumi up --yes && pulumi stack output fleetBucketNames
```{{exec}}

关键观察：打开 `dev` 的配置文件，你会看到 app: 的键与项目自己的 pulumi-config: 键**和平共处**，前缀不同、互不覆盖：

```bash
cat Pulumi.dev.yaml
```{{exec}}

这就是命名空间隔离的价值。组件作者用 `new pulumi.Config("app")` 圈出 app: 这块键空间，宿主项目用默认构造的 Config 圈出 pulumi-config: 这块；即便两边都有名为 bucketPrefix 的键，存进同一份 Pulumi.dev.yaml 也不会打架。可复用组件正是靠这一点，做到「自带配置、即插即用」。
