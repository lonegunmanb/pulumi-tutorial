#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-how-pulumi-works-aws"
export SCENARIO_TITLE="Pulumi 是如何工作的：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done
mkdir -p /root/workspace

# 给小内存实验机准备一块 swap，失败不影响后续。
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null || true
  chmod 600 /swapfile 2>/dev/null || true
  mkswap /swapfile >/dev/null 2>&1 || true
  swapon /swapfile >/dev/null 2>&1 || true
fi

# 安装 Pulumi、Node.js 与共享工具（尽力而为，单步失败不影响后续）。
bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi
if ! grep -q 'TS_NODE_TRANSPILE_ONLY' /root/.bashrc 2>/dev/null; then
  echo 'export TS_NODE_TRANSPILE_ONLY=1' >> /root/.bashrc
fi
if ! grep -q 'NODE_OPTIONS' /root/.bashrc 2>/dev/null; then
  echo 'export NODE_OPTIONS=--max-old-space-size=512' >> /root/.bashrc
fi

apt-get install -y jq curl >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/workspace/variants
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-how-works-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-how-pulumi-works-aws-lab",
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
    "strict": true,
    "target": "es2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "ts-node": {
    "transpileOnly": true
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: pulumi-how-pulumi-works-aws
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Observe how Pulumi registers, diffs and updates AWS resources against MiniStack.
YAML

read -r -d '' PROVIDER_TS <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as s3 from "@pulumi/aws/s3";
import { Provider } from "@pulumi/aws/provider";

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
TS

cat > variants/base.ts <<TS
${PROVIDER_TS}

const mediaBucket = new s3.Bucket("media-bucket", {
  tags: { owner: "media-team", phase: "initial" },
}, { provider: localAws });

const contentBucket = new s3.Bucket("content-bucket", {
  tags: { owner: "content-team", phase: "initial" },
}, { provider: localAws });

export const mediaPhysicalName = mediaBucket.bucket;
export const contentPhysicalName = contentBucket.bucket;
export const contentPhysicalId = contentBucket.id;
export const operationHint = pulumi
  .all([mediaBucket.bucket, contentBucket.bucket])
  .apply(([mediaName, contentName]) => "Engine registered " + mediaName + " and " + contentName + ", then the AWS provider called MiniStack.");
TS

cat > variants/step3-update.ts <<TS
${PROVIDER_TS}

const mediaBucket = new s3.Bucket("media-bucket", {
  tags: { owner: "media-team", phase: "tagged" },
}, { provider: localAws });

const contentBucket = new s3.Bucket("content-bucket", {
  tags: { owner: "content-team", phase: "initial" },
}, { provider: localAws });

export const mediaPhysicalName = mediaBucket.bucket;
export const contentPhysicalName = contentBucket.bucket;
export const contentPhysicalId = contentBucket.id;
TS

cat > variants/step4-rename.ts <<TS
${PROVIDER_TS}

const mediaBucket = new s3.Bucket("media-bucket", {
  tags: { owner: "media-team", phase: "tagged" },
}, { provider: localAws });

const appBucket = new s3.Bucket("app-bucket", {
  tags: { owner: "content-team", phase: "renamed" },
}, { provider: localAws });

export const mediaPhysicalName = mediaBucket.bucket;
export const appPhysicalName = appBucket.bucket;
TS

cat > variants/step5-delete.ts <<TS
${PROVIDER_TS}

const mediaBucket = new s3.Bucket("media-bucket", {
  tags: { owner: "media-team", phase: "tagged" },
}, { provider: localAws });

export const mediaPhysicalName = mediaBucket.bucket;
TS

cp variants/base.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true

# 启动 MiniStack 并等待健康检查通过，确保学员到达 step1 时模拟器已就绪。
docker compose up -d >/dev/null 2>&1 || true
for attempt in $(seq 1 60); do
  if curl -fs http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    echo "MiniStack 已就绪。"
    break
  fi
  sleep 2
done

touch /tmp/.setup-done
echo "[$(date +%Y-%m-%dT%H:%M:%S)] AWS / MiniStack how-pulumi-works lab is ready in /root/workspace"