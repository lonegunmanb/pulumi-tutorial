# 生成 PR Preview 工作流

现在把本地验证步骤写成 GitHub Actions 工作流。这个示例使用本地 Backend，并把 MiniStack 作为 service container 启动；真实团队应换成自管理 Backend，并由 CI 安全注入云凭据。

先创建工作流目录：

```bash
cd /root/workspace && \
mkdir -p .github/workflows
```{{exec}}

写入 GitHub Actions 文件。它会在 Pull Request 中运行单元测试，再通过 Pulumi GitHub Action 执行 preview。

```bash
cd /root/workspace && \
cat > .github/workflows/pulumi-preview.yml <<'YAML'
name: Pulumi preview

on:
  pull_request:

permissions:
  contents: read

concurrency:
  group: pulumi-pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  preview:
    runs-on: ubuntu-latest
    services:
      ministack:
        image: ministackorg/ministack:latest
        ports:
          - 4566:4566
        env:
          MINISTACK_REGION: us-east-1
          MINISTACK_ACCOUNT_ID: "000000000000"
    env:
      PULUMI_CONFIG_PASSPHRASE: ""
      AWS_ACCESS_KEY_ID: test
      AWS_SECRET_ACCESS_KEY: test
      AWS_REGION: us-east-1
      AWS_DEFAULT_REGION: us-east-1
      TS_NODE_TRANSPILE_ONLY: "1"
      NODE_OPTIONS: --max-old-space-size=512
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run test:unit
      - run: |
          for attempt in $(seq 1 60); do
            curl -sf http://localhost:4566/_ministack/health && exit 0
            sleep 2
          done
          exit 1

      - uses: pulumi/setup-pulumi@v2
      - run: pulumi login --local
      - run: pulumi stack select dev || pulumi stack init dev
      - run: pulumi config set prefix ci

      - uses: pulumi/actions@v7
        with:
          command: preview
          stack-name: dev
          work-dir: .
YAML
```{{exec}}

查看生成结果：

```bash
cd /root/workspace && \
sed -n '1,240p' .github/workflows/pulumi-preview.yml
```{{exec}}

注意 concurrency 的作用：同一个 Pull Request 只保留最新一次 preview，避免旧提交上的结果覆盖新提交。