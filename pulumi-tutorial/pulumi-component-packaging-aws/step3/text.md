# 查看 source-based package

Source-based package 是 Pulumi Package。它通过源代码承载组件，消费者运行 `pulumi package add` 时才生成本地 SDK。

先看最小包结构：

```bash
find /root/repos/aws-secure-bucket-source-work -maxdepth 1 -type f | sort
```{{exec}}

再看插件清单和语言清单：

```bash
cd /root/repos/aws-secure-bucket-source-work && \
cat PulumiPlugin.yaml && \
cat package.json
```{{exec}}

这里的 `PulumiPlugin.yaml` 声明作者语言是 nodejs。入口文件由 package.json 的 main 字段指向，Pulumi 会从入口模块导出的组件类推断 schema。

查看仓库中的 tag：

```bash
git -C /root/repos/aws-secure-bucket-source-work log --oneline --decorate -1
```{{exec}}

真实远端仓库的命令形式与本地实验一致，只是把 file URL 换成 GitHub 或 GitLab 地址。