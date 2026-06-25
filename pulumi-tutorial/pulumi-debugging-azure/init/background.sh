#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-debugging-azure"
export SCENARIO_TITLE="Pulumi 调试与故障排查（Azure / miniblue）"
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

apt-get install -y curl jq openssl >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/workspace/debugging-azure
cd /root/workspace/debugging-azure

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-39cc27a
    container_name: pulumi-debugging-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

docker compose up -d

for attempt in $(seq 1 60); do
  if curl -sf http://localhost:4566/health >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" = "60" ]; then
    docker compose logs
    exit 1
  fi
  sleep 2
done

mkdir -p /root/.miniblue
for attempt in $(seq 1 60); do
  if curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 > /root/.miniblue/cert.pem 2>/dev/null || true
cp /root/.miniblue/cert.pem /usr/local/share/ca-certificates/miniblue.crt 2>/dev/null || true
update-ca-certificates >/dev/null 2>&1 || true

cat > /root/.pulumi-debugging-azure-env.sh <<'SH'
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
export SSL_CERT_FILE=/root/.miniblue/cert.pem
SH

if ! grep -q '.pulumi-debugging-azure-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-debugging-azure-env.sh' >> /root/.bashrc
fi

cat > package.json <<'JSON'
{
  "name": "debugging-azure-lab",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@pulumi/azure": "^6.0.0",
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
name: debugging-azure
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Debug Pulumi updates against a miniblue Azure endpoint.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

const config = new pulumi.Config();

const owner = config.require("owner");
const environment = config.require("environment");
const location = config.get("location") ?? "eastus";
const namePrefix = config.get("namePrefix") ?? "debug-lab";
const diagnosticTag = config.get("diagnosticTag") ?? "normal";
const breakProvider = config.getBoolean("breakProvider") ?? false;

const metadataHost = breakProvider ? "localhost:5999" : "localhost:4567";

pulumi.log.info(`Preparing ${location} Resource Group for ${owner}.`);
pulumi.log.debug(`miniblue metadata host selected by config: ${metadataHost}`);

const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost,
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

const group = new azure.core.ResourceGroup("diagnostic-rg", {
  name: `${namePrefix}-${environment}-rg`,
  location,
  tags: {
    owner,
    environment,
    diagnostic: diagnosticTag,
    managedBy: "pulumi",
  },
}, { provider: miniblue });

export const resourceGroupName = group.name;
export const resourceGroupId = group.id;
export const selectedMetadataHost = metadataHost;
export const tagValue = diagnosticTag;
TS

npm install --no-audit --no-fund >/dev/null

pulumi login --local >/dev/null
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null

touch /tmp/.setup-done
echo "Pulumi debugging Azure lab is ready in /root/workspace/debugging-azure"