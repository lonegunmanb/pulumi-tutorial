#!/usr/bin/env bash
set -o pipefail

export SCENARIO_ID="pulumi-architecture-aws"
export SCENARIO_TITLE="Pulumi 架构解析：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

mkdir -p /root/workspace

# 安装 Pulumi、Node.js 与共享工具（尽力而为，单步失败不影响后续）。
bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi

# Killercoda 已预装 Docker，这里只确保守护进程在运行。
service docker start >/dev/null 2>&1 || true

# 安装 AWS CLI v2（供 awslocal 使用），失败不致命。
if ! command -v aws >/dev/null 2>&1; then
  apt-get install -y unzip >/dev/null 2>&1 || true
  if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null; then
    unzip -o -q /tmp/awscliv2.zip -d /tmp >/dev/null 2>&1 \
      && /tmp/aws/install --update >/dev/null 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
  fi
  # 官方安装包失败时，退而使用 apt 包。
  command -v aws >/dev/null 2>&1 || apt-get install -y awscli >/dev/null 2>&1 || true
fi

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

cat > /usr/local/bin/awslocal <<'WRAPPER'
#!/usr/bin/env bash
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
exec aws --endpoint-url=http://localhost:4566 --region "$AWS_DEFAULT_REGION" "$@"
WRAPPER
chmod +x /usr/local/bin/awslocal

mkdir -p /root/workspace
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-arch-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-architecture-aws-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@pulumi/aws": "^7.0.0",
    "@pulumi/pulumi": "^3.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.0.0"
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: pulumi-architecture-aws
runtime:
  name: nodejs
description: Understand Pulumi architecture with AWS Provider and MiniStack.
YAML

cat > index.ts <<'TS'
import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

const localAws = new aws.Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [
    {
      s3: "http://localhost:4566",
      sts: "http://localhost:4566",
    },
  ],
});

const mediaBucket = new aws.s3.Bucket("media-bucket", {
  bucket: "pulumi-arch-media-bucket",
  tags: {
    owner: "media-team",
    stage: "first-up",
  },
}, { provider: localAws });

const contentBucket = new aws.s3.Bucket("content-bucket", {
  bucket: "pulumi-arch-content-bucket",
  tags: {
    owner: "content-team",
  },
}, { provider: localAws });

export const mediaBucketName = mediaBucket.bucket;
export const contentBucketName = contentBucket.bucket;
export const architectureHint = pulumi.interpolate`Engine registered ${mediaBucket.bucket} and ${contentBucket.bucket}, then the AWS provider called MiniStack.`;
TS

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "AWS / MiniStack lab is ready in /root/workspace"