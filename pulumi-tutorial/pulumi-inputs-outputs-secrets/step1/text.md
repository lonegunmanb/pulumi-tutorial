# 读取输出

```bash
cd /root/workspace
pulumi up --yes
pulumi stack output
```{{exec}}

`resourceName` 和 `message` 都来自资源输出。正文中会解释为什么这些值在程序运行时表现为 `Output<T>`。