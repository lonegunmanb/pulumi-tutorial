# 第一次 preview 与 up

MiniStack 已在后台启动。先确认本地 AWS 模拟器健康：

```bash
cd /root/workspace && curl -s http://localhost:4566/_ministack/health | jq .
```{{exec}}

看一眼初始程序：

```bash
cat /root/workspace/index.ts
```{{exec}}

程序里声明了两个 S3 Bucket。执行 `new Bucket` 时，语言宿主只是把“期望状态”注册给 Engine，还没有直接创建云资源。

先预览这张期望状态会带来什么操作：

```bash
cd /root/workspace && pulumi preview --diff
```{{exec}}

你会看到两个 Bucket 都是 `+`。这表示 State 里还没有这些资源，所以 Engine 计划创建它们。

确认预览后执行部署：

```bash
pulumi up --yes
```{{exec}}

这一步完成后，Provider 已经调用 MiniStack 创建资源，Engine 也把结果写回了本地 State。