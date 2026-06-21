# 第一次 preview 与 up

miniblue 已在后台启动。先确认本地 Azure 模拟器的 metadata 端口可用：

```bash
cd /root/workspace && curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" | jq .
```{{exec}}

看一眼初始程序：

```bash
cat /root/workspace/index.ts
```{{exec}}

程序里声明了两个 Resource Group。构造资源对象时，语言宿主只是向 Engine 注册期望状态，并不会直接创建 Azure 资源。

先预览这张期望状态会带来什么操作：

```bash
cd /root/workspace && pulumi preview --diff
```{{exec}}

你会看到两个 Resource Group 都是 `+`。这表示 State 里还没有这些资源，所以 Engine 计划创建它们。

确认预览后执行部署：

```bash
pulumi up --yes
```{{exec}}

这一步完成后，Provider 已经调用 miniblue 创建资源，Engine 也把结果写回了本地 State。