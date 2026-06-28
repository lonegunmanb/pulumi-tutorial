# 理解 Git 仓库分发

本实验使用的是本地路径。团队共享 template 时，通常把这个目录放进 Git 仓库，再用 URL 创建项目。

```bash
cat <<'TEXT'
pulumi new https://github.com/myorg/my-template
pulumi new https://github.com/myorg/templates/tree/main/aws-typescript
pulumi new https://github.com/myorg/my-template/tree/v1.0.0
TEXT
```{{exec}}

如果一个仓库里有多个 template，每个子目录都应当可以独立被 `pulumi new` 消费。不要让模板依赖旁边目录里的隐藏文件。

本实验不安排手动清理命令。Killercoda 会在会话结束后回收临时环境。
