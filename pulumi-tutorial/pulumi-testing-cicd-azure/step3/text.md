# 用 Automation API 部署到 miniblue

单元测试验证了资源输入。集成测试要验证 Pulumi 生命周期本身：创建临时 Stack、预览、更新到 miniblue、读取输出、检查状态，最后销毁。

这里要特意观察速度差异：即使 miniblue 是本地模拟环境，Automation API 仍然要启动 Pulumi CLI、加载 Azure provider、执行 preview 和 up，所以会比上一页的 mock 单元测试慢很多。代码中的命名、标签、配置解析和组件输入逻辑，主要应靠单元测试覆盖；这里的集成测试负责确认整条部署生命周期能跑通。

写一个 Mocha 集成测试。它使用 Automation API 操作当前目录里的 Pulumi 程序。测试代码已经由初始化脚本放在 asserts 目录中，这里先查看内容，再复制到测试目录。

```bash
cd /root/workspace && \
mkdir -p test && \
cat asserts/integration.spec.ts && \
cp asserts/integration.spec.ts test/integration.spec.ts
```{{exec}}

运行集成测试。第一次运行可能会下载 Azure provider 插件，因此会比单元测试慢。

```bash
cd /root/workspace && \
npm run test:integration
```{{exec}}

测试结束后，临时 Stack 会被 destroy 并删除。你可以确认当前工作区只剩 dev Stack。

```bash
cd /root/workspace && \
pulumi stack ls
```{{exec}}
