# 生成 CI 骨架

创建 GitHub Actions 目录：

```bash
mkdir -p .github/workflows
cat > .github/workflows/pulumi-preview.yml <<'YAML'
name: Pulumi Preview
on: [pull_request]
jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: pulumi login --local && pulumi stack select dev && pulumi preview
YAML
```{{exec}}

正式章节会补充 Pulumi Cloud、OIDC、环境保护和审批门禁。