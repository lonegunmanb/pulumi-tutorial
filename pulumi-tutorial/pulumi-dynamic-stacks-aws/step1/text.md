# 读取环境配置矩阵

MiniStack 已经在后台启动。先确认本地 AWS 模拟器健康，并查看这份实验的代码与配置矩阵：

```bash
cd /root/workspace && \
curl -s http://localhost:4566/_ministack/health | jq . && \
printf '\n--- Pulumi.dev.yaml ---\n' && sed -n '1,220p' Pulumi.dev.yaml && \
printf '\n--- Pulumi.prod.yaml ---\n' && sed -n '1,220p' Pulumi.prod.yaml && \
printf '\n--- index.ts ---\n' && sed -n '1,240p' index.ts
```{{exec}}

这一步不要急着部署。先观察 dev 与 prod 的差异：dev 只有 1 个数据桶，prod 有 2 个数据桶，并且 prod 开启访问日志桶。

再看程序中的 `settings`。资源数量、标签、区域和日志开关都来自配置对象，而不是散落在代码里的环境判断。

最后确认当前工作目录已经有一条 Git 基线，后面做配置恢复时会用到它：

```bash
git status --short && git log --oneline -1
```{{exec}}
