# 编写组件并托管到 Git

环境已经创建两个本地 Git 仓库。先看 source-based package 里的组件入口：

```bash
sed -n '1,220p' /root/repos/azure-secure-storage-source-work/index.ts
```{{exec}}

这个 `SecureStorage` 组件把资源组、主存储账户和日志账户封装成一个组件资源。子资源会继承消费者传入组件的 miniblue provider。

再看这个组件仓库已经打好的版本标签：

```bash
git -C /root/repos/azure-secure-storage-source-work tag --list
```{{exec}}

实验用本地 bare repository 模拟远端 Git 仓库。真实项目中，同样的 tag 会推送到 GitHub、GitLab 或自建 Git 服务。

```bash
git --git-dir=/root/repos/azure-secure-storage-source.git show-ref --tags
```{{exec}}

下一步先走 native language package 路径，它不经过 Pulumi Package 层，只使用 npm 从 Git tag 安装同语言组件。