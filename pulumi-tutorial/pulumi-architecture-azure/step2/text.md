# 阅读 Dynamic Provider

这一步先不要急着部署，先看程序本身在表达什么。Pulumi 的核心思路是：你用代码描述“我想要什么资源”，Pulumi 再负责把这份描述变成实际的创建、更新或删除动作。

先查看这个 Pulumi Python 程序：

```bash
cd /root/workspace && \
cat Pulumi.yaml && \
sed -n '1,260p' __main__.py
```{{exec}}

这里最值得关注的是：它没有使用官方 `pulumi-azure-native` Provider，而是自己写了一个 Dynamic Provider，并在里面实现 `create()` 和 `delete()`。

你可以这样理解这几个角色：
- **Pulumi Program**：就是 `__main__.py` 这份代码，负责描述你想要的资源。
- **Pulumi Engine**：负责运行程序、比较差异、安排执行顺序。
- **Provider**：负责把 Engine 的指令翻译成目标平台的 API 调用。

这个示例故意使用 Dynamic Provider，不是因为生产里一定要这么做，而是因为它更适合教学：你可以直接看到 Provider 的本质，就是“接收资源生命周期操作，再把它们翻译成 Azure 风格 API 调用”。