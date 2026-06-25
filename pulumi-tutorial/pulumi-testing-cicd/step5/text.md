# 串起本地验证流水线

最后用 `act` 在本地真实执行一次 PR preview 工作流。这里使用的就是上一页生成的同一份 GitHub Actions YAML；工作流会确认 MiniStack 可用，然后通过 Pulumi GitHub Action 执行 preview。

```bash
cd /root/workspace && \
docker info >/dev/null && \
act pull_request -W .github/workflows/pulumi-preview.yml -j preview -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest --container-architecture linux/amd64 --container-options '--network host'
```{{exec}}

act 使用 Docker 模拟 GitHub Actions runner。上面指定的 runner 镜像来自 act 社区，适合本地实验，不代表 GitHub 托管 runner 与它完全一致。`--network host` 让 act 容器可以访问宿主机上已经启动的 MiniStack。

如果你只想先查看 act 会执行哪些步骤，可以加上 dry-run 参数：

```bash
cd /root/workspace && \
act pull_request -W .github/workflows/pulumi-preview.yml -j preview -n -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
```{{exec}}

最后再运行 Automation API 集成测试。这里会重新从 asserts 目录准备测试文件，所以即使你刷新过终端或跳过了前面的复制步骤，也能直接运行。测试会创建自己的临时 Stack，并在结束时清理。

```bash
cd /root/workspace && \
mkdir -p test && \
cp asserts/integration.spec.ts test/integration.spec.ts && \
npm run test:integration
```{{exec}}

如果上面的命令全部通过，你就拥有了一个最小但完整的 Pulumi TDD 与 PR preview 闭环。后续可以把规则扩展到标签、安全输入、Policy Pack 和真实云环境。

最后查看工作区文件：

```bash
cd /root/workspace && \
find . -maxdepth 3 -type f | sort
```{{exec}}