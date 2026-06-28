# 编写组件并托管到 Git

环境已经创建两个本地 Git 仓库。先看 source-based package 里的组件入口：

```bash
sed -n '1,180p' /root/repos/aws-secure-bucket-source-work/index.ts
```{{exec}}

这个 `SecureBucket` 组件把主桶和日志桶封装成一个组件资源。它的子资源都以组件实例名为前缀，并通过 parent 归到组件下面。

再看这个组件仓库已经打好的版本标签：

```bash
git -C /root/repos/aws-secure-bucket-source-work tag --list
```{{exec}}

实验用本地 bare repository 模拟远端 Git 仓库。真实项目中，同样的 tag 会推送到 GitHub、GitLab 或自建 Git 服务。

```bash
git --git-dir=/root/repos/aws-secure-bucket-source.git show-ref --tags
```{{exec}}

下一步先走 native language package 路径，它不经过 Pulumi Package 层，只使用 npm 从 Git tag 安装同语言组件。