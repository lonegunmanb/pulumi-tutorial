#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-state-backends-aws"
export SCENARIO_TITLE="State 与 Backend（AWS / MiniStack）"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

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

# awslocal 是 AWS CLI 的包装器，不能脱离 aws 二进制工作。
# 优先安装 AWS CLI v2；apt 包只作为非致命 fallback，避免 apt 源缺包导致初始化失败。
if ! command -v aws >/dev/null 2>&1; then
  apt-get install -y unzip >/dev/null 2>&1 || true
  if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null; then
    unzip -o -q /tmp/awscliv2.zip -d /tmp >/dev/null 2>&1 \
      && /tmp/aws/install --update >/dev/null 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
  fi
  command -v aws >/dev/null 2>&1 || apt-get install -y awscli >/dev/null 2>&1 || true
fi

cat > /usr/local/bin/awslocal <<'WRAPPER'
#!/usr/bin/env bash
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
exec aws --endpoint-url=http://localhost:4566 --region "$AWS_DEFAULT_REGION" "$@"
WRAPPER
chmod +x /usr/local/bin/awslocal

mkdir -p /root/workspace/state-backends-aws
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-state-backends-ministack
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

awslocal s3 mb s3://pulumi-state-aws >/dev/null 2>&1 || true

cat > /root/.pulumi-state-env.sh <<'SH'
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export PULUMI_CONFIG_PASSPHRASE=""
export PULUMI_BACKEND_URL='s3://pulumi-state-aws?endpoint=localhost:4566&disableSSL=true&s3ForcePathStyle=true&region=us-east-1&awssdk=v2'
SH

if ! grep -q '.pulumi-state-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-state-env.sh' >> /root/.bashrc
fi

cd /root/workspace/state-backends-aws

cat > package.json <<'JSON'
{
  "name": "state-backends-aws-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@pulumi/pulumi": "^3.0.0",
    "@pulumi/random": "^4.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.0.0"
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: state-backends-aws
runtime:
  name: nodejs
description: Explore Pulumi state and DIY backends with an S3-compatible MiniStack bucket.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";

const stack = pulumi.getStack();
const config = new pulumi.Config();

const service = config.get("service") ?? "catalog";
const owner = config.get("owner") ?? "platform";
const operatorToken = config.requireSecret("operatorToken");

const deploymentName = new random.RandomPet("deployment-name", {
  prefix: `${service}-${stack}`,
  length: 2,
});

export const stackName = stack;
export const serviceName = service;
export const ownerName = owner;
export const deploymentNameValue = deploymentName.id;
export const operatorTokenPreview = operatorToken;
TS

cat > Pulumi.with-backend.yaml <<YAML
name: state-backends-aws
runtime:
  name: nodejs
description: Explore Pulumi state and DIY backends with an S3-compatible MiniStack bucket.
backend:
  url: "s3://pulumi-state-aws?endpoint=localhost:4566&disableSSL=true&s3ForcePathStyle=true&region=us-east-1&awssdk=v2"
YAML

npm install --no-audit --no-fund >/dev/null

touch /tmp/.setup-done
echo "State Backend AWS lab is ready in /root/workspace/state-backends-aws"
