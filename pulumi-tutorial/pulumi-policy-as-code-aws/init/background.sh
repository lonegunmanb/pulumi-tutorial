#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-policy-as-code-aws"
export SCENARIO_TITLE="Policy as Code（AWS / MiniStack）"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done

bash /root/setup-common.sh
export PATH="$HOME/.pulumi/bin:$PATH"

service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/workspace/policy-as-code-aws/app/variants /root/workspace/policy-as-code-aws/policy-pack
cd /root/workspace/policy-as-code-aws

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-policy-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

docker compose up -d

for attempt in $(seq 1 60); do
  if curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" = "60" ]; then
    docker compose logs
    exit 1
  fi
  sleep 2
done

cat > /root/.pulumi-policy-env.sh <<'SH'
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
SH

if ! grep -q '.pulumi-policy-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-policy-env.sh' >> /root/.bashrc
fi

cd /root/workspace/policy-as-code-aws/app

cat > package.json <<'JSON'
{
  "name": "policy-as-code-aws-app",
  "version": "1.0.0",
  "private": true,
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

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: policy-as-code-aws
runtime:
  name: nodejs
description: AWS policy-as-code lab against MiniStack.
YAML

cat > variants/bad.ts <<'TS'
import { Provider } from "@pulumi/aws/provider";
import * as s3 from "@pulumi/aws/s3";

const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566" }],
});

const bucket = new s3.Bucket("assets", {
  bucket: "tmp-assets-policy-lab",
  forceDestroy: true,
  tags: {
    environment: "dev",
  },
}, { provider: localAws });

export const bucketName = bucket.bucket;
TS

cat > variants/good.ts <<'TS'
import { Provider } from "@pulumi/aws/provider";
import * as s3 from "@pulumi/aws/s3";

const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566" }],
});

const bucket = new s3.Bucket("assets", {
  bucket: "policy-lab-assets-dev",
  forceDestroy: true,
  tags: {
    environment: "dev",
    owner: "platform-team",
    managedBy: "pulumi",
  },
}, { provider: localAws });

export const bucketName = bucket.bucket;
TS

cp variants/bad.ts index.ts

npm install --no-audit --no-fund >/dev/null

cd /root/workspace/policy-as-code-aws/policy-pack

cat > package.json <<'JSON'
{
  "name": "policy-as-code-aws-pack",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@pulumi/policy": "^1.21.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.0.0"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
JSON

cat > PulumiPolicy.yaml <<'YAML'
runtime: nodejs
version: 0.1.0
description: Local AWS policy pack for tagging and naming checks.
author: Pulumi Tutorial
YAML

cat > index.ts <<'TS'
import { PolicyPack } from "@pulumi/policy";
import type { ResourceValidationPolicy, StackValidationPolicy } from "@pulumi/policy";

const bucketType = "aws:s3/bucket:Bucket";

const requireBucketTags: ResourceValidationPolicy = {
  name: "aws-s3-required-tags",
  description: "S3 buckets must declare owner and managedBy tags.",
  enforcementLevel: "mandatory",
  validateResource: (args, reportViolation) => {
    if (args.type !== bucketType) {
      return;
    }
    const tags = (args.props.tags || {}) as Record<string, string>;
    if (!tags.owner) {
      reportViolation("S3 bucket must include an owner tag.");
    }
    if (tags.managedBy !== "pulumi") {
      reportViolation("S3 bucket must set managedBy to pulumi.");
    }
  },
};

const bucketNamePrefix: ResourceValidationPolicy = {
  name: "aws-s3-policy-lab-prefix",
  description: "S3 buckets should use the policy-lab prefix in this tutorial.",
  enforcementLevel: "advisory",
  validateResource: (args, reportViolation) => {
    if (args.type !== bucketType) {
      return;
    }
    const bucketName = String(args.props.bucket || args.props.bucketPrefix || "");
    if (!bucketName.startsWith("policy-lab-")) {
      reportViolation(`S3 bucket should start with policy-lab-. Current value: ${bucketName}`);
    }
  },
};

const maxBucketCount: StackValidationPolicy = {
  name: "aws-s3-maximum-count",
  description: "Stacks in this tutorial may contain at most two S3 buckets.",
  enforcementLevel: "mandatory",
  validateStack: (args, reportViolation) => {
    const count = args.resources.filter(resource => resource.type === bucketType).length;
    if (count > 2) {
      reportViolation(`Stack contains ${count} S3 buckets; maximum allowed is 2.`);
    }
  },
};

new PolicyPack("policy-as-code-aws", {
  policies: [requireBucketTags, bucketNamePrefix, maxBucketCount],
});
TS

npm install --no-audit --no-fund >/dev/null

pulumi login --local >/dev/null

touch /tmp/.setup-done
echo "Policy as Code AWS lab is ready in /root/workspace/policy-as-code-aws"