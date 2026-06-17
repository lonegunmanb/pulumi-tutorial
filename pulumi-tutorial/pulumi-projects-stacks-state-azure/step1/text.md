# 认识 Project 与启动 miniblue

这一步的目标：为练习搭建一个“离线”的 Azure 风格环境，让你不用真实云账号也能运行示例。我们会启动名为 `miniblue` 的本地模拟器（它在本机提供与 Azure 类似的 API，监听 `localhost:4566`），然后查看这个 Pulumi Project 的结构与入口代码。

先启动本地模拟器（可能需要一些时间来拉取镜像并启动容器）：

```bash
cd /root/workspace && \
docker compose up -d && \
docker compose ps
```{{exec}}

然后查看 Project 文件与程序入口，帮助你理解 Pulumi 怎么组织代码与元数据：

```bash
cd /root/workspace/azure-infra && \
ls -la && \
cat Pulumi.yaml && \
sed -n '1,180p' __main__.py
```{{exec}}

说明要点：
- **miniblue**：本地模拟器，提供类似 Azure 的接口以便练习时不依赖真实账户或网络资源。
- **Project（Pulumi.yaml）**：描述此 Pulumi 程序的元信息（名称、运行时等），不同 Project 会把配置键名前缀化以避免冲突。
- **Program（__main__.py）**：Pulumi 在运行时执行的代码，负责定义要创建的“资源”。本示例使用 Python 的 Dynamic Provider 调用 miniblue，而非直接调用真实 Azure SDK。
- 本章重点不是 Azure API 的细节，而是理解 **Project、Stack、Config、Secret、Output、State** 这些概念如何协同工作。