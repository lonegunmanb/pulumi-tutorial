#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-debugging-aws"
export SCENARIO_TITLE="Pulumi 调试与故障排查（AWS / LocalStack）"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done

if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null || true
  chmod 600 /swapfile 2>/dev/null || true
  mkswap /swapfile >/dev/null 2>&1 || true
  swapon /swapfile >/dev/null 2>&1 || true
fi

bash /root/setup-common.sh
export PATH="$HOME/.pulumi/bin:$PATH"

for line in 'export PULUMI_CONFIG_PASSPHRASE=""' 'export TS_NODE_TRANSPILE_ONLY=1' 'export NODE_OPTIONS=--max-old-space-size=512'; do
  grep -q "$line" /root/.bashrc 2>/dev/null || echo "$line" >> /root/.bashrc
done

service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

apt-get install -y unzip >/dev/null 2>&1 || true
if ! command -v aws >/dev/null 2>&1; then
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

mkdir -p /root/workspace/debugging-aws/variants
cd /root/workspace/debugging-aws

cat > docker-compose.yml <<'YAML'
services:
  localstack:
    image: localstack/localstack:3
    container_name: pulumi-debugging-localstack
    ports:
      - "4566:4566"
    environment:
      SERVICES: s3,sts
      DEFAULT_REGION: us-east-1
      EAGER_SERVICE_LOADING: "1"
    deploy:
      resources:
        limits:
          memory: 1536M
YAML

docker compose up -d

for attempt in $(seq 1 60); do
  if curl -sf http://localhost:4566/_localstack/health \
    | jq -e '.services.s3 == "available" or .services.s3 == "running"' >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" = "60" ]; then
    docker compose logs
    exit 1
  fi
  sleep 2
done

cat > /root/.pulumi-debugging-aws-env.sh <<'SH'
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
SH

if ! grep -q '.pulumi-debugging-aws-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-debugging-aws-env.sh' >> /root/.bashrc
fi

cat > package.json <<'JSON'
{
  "name": "debugging-aws-lab",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@pulumi/aws": "^6.0.0",
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
  },
  "ts-node": {
    "transpileOnly": true
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: debugging-aws
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Debug Pulumi updates against an S3-compatible LocalStack endpoint.
YAML

cat > variants/config-check.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();

const owner = config.require("owner");
const environment = config.require("environment");

pulumi.log.info(`Configuration is ready for ${environment}, owner ${owner}.`);

export const checkedOwner = owner;
export const checkedEnvironment = environment;
TS

cat > variants/resource.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { Provider } from "@pulumi/aws/provider";
import * as s3 from "@pulumi/aws/s3";

const config = new pulumi.Config();

const owner = config.require("owner");
const environment = config.require("environment");
const bucketPrefix = config.get("bucketPrefix") ?? "debug-lab";
const diagnosticTag = config.get("diagnosticTag") ?? "normal";
const breakProvider = config.getBoolean("breakProvider") ?? false;

const s3Endpoint = breakProvider ? "http://localhost:5999" : "http://localhost:4566";

pulumi.log.info(`Preparing ${environment} bucket for ${owner}.`);
pulumi.log.debug(`LocalStack S3 endpoint selected by config: ${s3Endpoint}`);

const localAws = new Provider("localstack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{ s3: s3Endpoint, sts: "http://localhost:4566" }],
});

const bucket = new s3.Bucket("diagnostic-bucket", {
  bucket: `${bucketPrefix}-${environment}-assets`,
  forceDestroy: true,
  tags: {
    owner,
    environment,
    diagnostic: diagnosticTag,
    managedBy: "pulumi",
  },
}, { provider: localAws });

export const bucketName = bucket.bucket;
export const bucketUrn = bucket.urn;
export const selectedEndpoint = s3Endpoint;
export const tagValue = diagnosticTag;
TS

cp variants/config-check.ts index.ts

npm install --no-audit --no-fund >/dev/null

pulumi login --local >/dev/null
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null

touch /tmp/.setup-done
echo "Pulumi debugging AWS lab is ready in /root/workspace/debugging-aws"