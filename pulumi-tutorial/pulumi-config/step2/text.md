# 在程序里读取配置驱动资源

光把值存进文件还不够，程序得能读到它们。看看初始程序怎么读配置：

```bash
cat /root/workspace/index.ts
```{{exec}}

程序里用一个 `Config` 对象读取配置，关键三行是：

- `config.require("bucketPrefix")`：必填项，缺失就直接报错；
- `config.getNumber("bucketCount") ?? 1`：可选项，缺失则用默认值 1；
- `new pulumi.Config("aws")`：换一个命名空间，去读 aws 命名空间下的键（aws:region）。

部署它（此时只设了 `bucketPrefix`，`bucketCount` 走默认值 1）：

```bash
pulumi up --yes
```{{exec}}

只建出 1 个桶。现在把数量改成 3，**不改一行代码**，再部署一次：

```bash
pulumi config set bucketCount 3
```{{exec}}

```bash
pulumi up --yes && pulumi stack output
```{{exec}}

这次新增了 2 个桶。配置驱动资源的威力就在这里：同一套逻辑，靠配置就能伸缩。

再看 `require` 的「快速失败」是什么样。先临时删掉必填项，预览会立刻报错：

```bash
pulumi config rm bucketPrefix && pulumi preview 2>&1 | head -n 20
```{{exec}}

`require` 在缺失时抛出带提示的异常，阻止部署带着空值继续。把它补回来：

```bash
pulumi config set bucketPrefix demo
```{{exec}}
