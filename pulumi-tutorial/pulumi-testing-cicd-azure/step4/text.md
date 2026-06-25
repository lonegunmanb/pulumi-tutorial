# 生成 PR Preview 工作流

现在把本地验证步骤写成 GitHub Actions 工作流。这个示例使用本地 Backend，并把 miniblue 作为 service container 启动；真实团队应换成自管理 Backend，并由 CI 安全注入云凭据。

先创建工作流目录：

```bash
cd /root/workspace && \
mkdir -p .github/workflows
```{{exec}}

写入 GitHub Actions 文件。它会在 Pull Request 中运行单元测试，再通过 Pulumi GitHub Action 执行 preview。工作流内容已经由初始化脚本放在 asserts 目录中，这里先查看内容，再复制到工作流目录。

```bash
cd /root/workspace && \
cat asserts/pulumi-preview.yml && \
cp asserts/pulumi-preview.yml .github/workflows/pulumi-preview.yml && \
cp asserts/pulumi-preview-act.yml .github/workflows/pulumi-preview-act.yml
```{{exec}}

查看生成结果：

```bash
cd /root/workspace && \
sed -n '1,280p' .github/workflows/pulumi-preview.yml
```{{exec}}

注意 concurrency 的作用：同一个 Pull Request 只保留最新一次 preview，避免旧提交上的结果覆盖新提交。另一个名为 pulumi-preview-act 的工作流只给本地 act 模拟使用，它复用当前已经启动的 miniblue，不再声明 service container。
