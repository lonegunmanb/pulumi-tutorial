# 串起本地验证流水线

最后在本地模拟一次 CI 流程。先用 act 检查 GitHub Actions 工作流会执行哪些步骤：

```bash
cd /root/workspace && \
act pull_request -W .github/workflows/pulumi-preview.yml -j preview -n
```{{exec}}

act 使用 Docker 模拟 GitHub Actions runner。如果当前环境可以访问 Docker，就实际运行一次 PR preview 工作流；如果 Docker 不可用，本步骤会跳过真实运行，只保留上面的 dry-run 结果。下面指定的 runner 镜像来自 act 社区，适合本地实验，不代表 GitHub 托管 runner 与它完全一致。

```bash
cd /root/workspace && \
if docker info >/dev/null 2>&1; then act pull_request -W .github/workflows/pulumi-preview.yml -j preview -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest --container-architecture linux/amd64; else echo "Docker 未就绪，已跳过 act 真实运行。"; fi
```{{exec}}

再运行本地完整验证：单元测试、preview、集成测试。集成测试会创建自己的临时 Stack，并在结束时清理。

```bash
cd /root/workspace && \
npm run test:unit && \
pulumi stack select dev && \
pulumi config set prefix ci && \
pulumi preview --non-interactive && \
npm run test:integration
```{{exec}}

如果上面的命令全部通过，你就拥有了一个最小但完整的 Pulumi TDD 与 PR preview 闭环。后续可以把规则扩展到标签、安全输入、Policy Pack 和真实云环境。

最后查看工作区文件：

```bash
cd /root/workspace && \
find . -maxdepth 3 -type f | sort
```{{exec}}