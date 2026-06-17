# 认识 Project 与启动 MiniStack

这一步先搭建实验环境，并顺手认识 Pulumi 里最基础的一个概念：**Project**。

你可以先把 Project 理解成“一份基础设施代码工程”。它有自己的项目名、运行时、入口文件，也就是一整套可重复执行的基础设施定义。

先启动本地 AWS 模拟器。`MiniStack` 会在 `localhost:4566` 暴露 AWS 风格 API，这样你不用真实 AWS 账号也能完成实验：

```bash
cd /root/workspace && \
docker compose up -d && \
docker compose ps
```{{exec}}

接着查看这个上游 Project 的结构：

```bash
cd /root/workspace/aws-infra && \
ls -la && \
cat Pulumi.yaml && \
sed -n '1,120p' index.ts
```{{exec}}

说明要点：
- `Pulumi.yaml` 定义这个 Project 的基本信息，例如项目名和运行时。
- `index.ts` 是程序入口，里面描述了希望创建什么资源。
- 这份代码会读取当前 Stack 的配置，再把 Bucket 名称、环境名和 Secret 作为 **Stack Outputs** 导出，供人或其他项目读取。

先记住一句话：**Project 是代码工程，Stack 是这份工程的某个具体环境实例**。后面几步会把这个区别讲清楚。