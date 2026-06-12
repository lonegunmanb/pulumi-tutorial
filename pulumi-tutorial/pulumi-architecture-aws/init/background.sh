#!/usr/bin/env bash
set -euo pipefail

export SCENARIO_ID="pulumi-architecture-aws"
export SCENARIO_TITLE="Pulumi 架构解析：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1

/root/setup-common.sh
export PATH="$HOME/.pulumi/bin:$PATH"

apt-get update >/dev/null
apt-get install -y docker.io awscli python3-pip >/dev/null
service docker start >/dev/null 2>&1 || true

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

npm install --no-audit --no-fund >/dev/null
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null
docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "AWS / MiniStack lab is ready in /root/workspace"