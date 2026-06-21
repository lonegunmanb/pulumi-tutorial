#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-dynamic-stacks-aws"
export SCENARIO_TITLE="动态 Stack 配置：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done
mkdir -p /root/workspace

if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null || true
  chmod 600 /swapfile 2>/dev/null || true
  mkswap /swapfile >/dev/null 2>&1 || true
  swapon /swapfile >/dev/null 2>&1 || true
fi

bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

for line in 'export PULUMI_CONFIG_PASSPHRASE=""' 'export TS_NODE_TRANSPILE_ONLY=1' 'export NODE_OPTIONS=--max-old-space-size=512'; do
  grep -q "$line" /root/.bashrc 2>/dev/null || echo "$line" >> /root/.bashrc
done

apt-get install -y unzip >/dev/null 2>&1 || true
if ! command -v aws >/dev/null 2>&1; then
  if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null; then
    unzip -o -q /tmp/awscliv2.zip -d /tmp >/dev/null 2>&1 \
      && /tmp/aws/install --update >/dev/null 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
  fi
  command -v aws >/dev/null 2>&1 || apt-get install -y awscli >/dev/null 2>&1 || true
fi

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

cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-dynamic-stacks-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-dynamic-stacks-aws-lab",
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
name: pulumi-dynamic-stacks-aws
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Drive AWS resources from dev/prod stack configuration against MiniStack.
config:
  pulumi-dynamic-stacks-aws:defaultOwner: platform-team
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as s3 from "@pulumi/aws/s3";
import { Provider } from "@pulumi/aws/provider";

interface EnvironmentSettings {
  namePrefix: string;
  region: string;
  bucketCount: number;
  dataClass: string;
  enableAccessLogs: boolean;
  tags: Record<string, string>;
}

const stack = pulumi.getStack();
const project = pulumi.getProject();
const config = new pulumi.Config();
const defaultOwner = config.require("defaultOwner");
const settings = config.requireObject<EnvironmentSettings>("settings");
const operationsToken = config.requireSecret("operationsToken");

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

const commonTags = {
  owner: defaultOwner,
  ...settings.tags,
  project,
  environment: stack,
  configuredRegion: settings.region,
  dataClass: settings.dataClass,
  managedBy: "pulumi",
};

const dataBuckets: s3.Bucket[] = [];
for (let index = 0; index < settings.bucketCount; index++) {
  dataBuckets.push(new s3.Bucket(`data-${index}`, {
    bucket: `${settings.namePrefix}-${stack}-data-${index}`,
    tags: {
      ...commonTags,
      role: "data",
      shard: String(index),
    },
  }, { provider: localAws }));
}

let accessLogsBucketName: pulumi.Output<string> = pulumi.output("disabled");
let accessLogsBucket: s3.Bucket | undefined;
if (settings.enableAccessLogs) {
  accessLogsBucket = new s3.Bucket("access-logs", {
    bucket: `${settings.namePrefix}-${stack}-logs`,
    tags: {
      ...commonTags,
      role: "access-logs",
    },
  }, { provider: localAws });
  accessLogsBucketName = accessLogsBucket.bucket;
}

const manifest = new s3.BucketObject("environment-manifest", {
  bucket: dataBuckets[0].bucket,
  key: "manifest.json",
  content: pulumi.jsonStringify({
    stack,
    settings,
    dataBuckets: dataBuckets.map((bucket) => bucket.bucket),
    accessLogsBucket: accessLogsBucketName,
  }),
}, {
  provider: localAws,
  dependsOn: accessLogsBucket ? [accessLogsBucket] : [],
});

export const environment = stack;
export const configuredRegion = settings.region;
export const bucketCount = settings.bucketCount;
export const dataBucketNames = pulumi.all(dataBuckets.map((bucket) => bucket.bucket));
export const primaryBucket = dataBuckets[0].bucket;
export const accessLogsEnabled = settings.enableAccessLogs;
export const accessLogsBucket = accessLogsBucketName;
export const manifestKey = manifest.key;
export const tokenHint = operationsToken.apply((value) => `token length: ${value.length}`);
TS

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true

pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
pulumi config set --path settings.namePrefix dynaws >/dev/null 2>&1 || true
pulumi config set --path settings.region us-east-1 >/dev/null 2>&1 || true
pulumi config set --path settings.bucketCount 1 >/dev/null 2>&1 || true
pulumi config set --path settings.dataClass test >/dev/null 2>&1 || true
pulumi config set --path settings.enableAccessLogs false >/dev/null 2>&1 || true
pulumi config set --path settings.tags.owner platform-dev >/dev/null 2>&1 || true
pulumi config set --path settings.tags.costCenter lab-dev >/dev/null 2>&1 || true
pulumi config set operationsToken dev-token-123 --secret >/dev/null 2>&1 || true

pulumi stack select prod >/dev/null 2>&1 || pulumi stack init prod >/dev/null 2>&1 || true
pulumi config set --path settings.namePrefix dynaws >/dev/null 2>&1 || true
pulumi config set --path settings.region us-west-2 >/dev/null 2>&1 || true
pulumi config set --path settings.bucketCount 2 >/dev/null 2>&1 || true
pulumi config set --path settings.dataClass restricted >/dev/null 2>&1 || true
pulumi config set --path settings.enableAccessLogs true >/dev/null 2>&1 || true
pulumi config set --path settings.tags.owner platform-prod >/dev/null 2>&1 || true
pulumi config set --path settings.tags.costCenter lab-prod >/dev/null 2>&1 || true
pulumi config set operationsToken prod-token-456 --secret >/dev/null 2>&1 || true

pulumi stack select dev >/dev/null 2>&1 || true
mkdir -p backups

git init >/dev/null 2>&1 || true
git config user.email pulumi-lab@example.com >/dev/null 2>&1 || true
git config user.name "Pulumi Lab" >/dev/null 2>&1 || true
git add Pulumi.yaml Pulumi.dev.yaml Pulumi.prod.yaml index.ts package.json tsconfig.json docker-compose.yml >/dev/null 2>&1 || true
git commit -m "Initial dynamic stack config lab" >/dev/null 2>&1 || true

docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true
docker compose up -d >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  curl -fs http://localhost:4566/_ministack/health >/dev/null 2>&1 && break
  sleep 2
done

touch /tmp/.setup-done
echo "AWS / MiniStack dynamic stacks lab is ready in /root/workspace"
