# 用 Automation API 部署到 miniblue

单元测试验证了资源输入。集成测试要验证 Pulumi 生命周期本身：创建临时 Stack、预览、更新到 miniblue、读取输出、检查状态，最后销毁。

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
