#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-state-backends-azure"
export SCENARIO_TITLE="State 与 Backend（Azure / miniblue）"
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

mkdir -p /root/workspace/state-backends-azure
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-6d934ae
    container_name: pulumi-state-backends-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
      MINIBLUE_STORAGE_ENDPOINT: http://localhost:4566
      MINIBLUE_DISABLE_SHAREDKEY_AUTH: "1"
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

cid=$(docker compose ps -q miniblue 2>/dev/null || true)
if [ -z "$cid" ]; then
  cid=$(docker ps -q --filter "name=pulumi-state-backends-miniblue" | head -1)
fi
if [ -n "$cid" ]; then
  docker cp "$cid:/azlocal" /usr/local/bin/azlocal 2>/dev/null || true
  chmod +x /usr/local/bin/azlocal 2>/dev/null || true
fi

azlocal storage container create --account pulumistate --name pulumi-state >/dev/null

cat > /root/.pulumi-state-env.sh <<'SH'
export AZURE_STORAGE_ACCOUNT=pulumistate
export AZURE_STORAGE_KEY=dGVzdA==
export LOCAL_AZURE_ENDPOINT=http://localhost:4566
export PULUMI_CONFIG_PASSPHRASE=""
export PULUMI_BACKEND_URL='azblob://pulumi-state?storage_account=pulumistate&protocol=http&domain=localhost:4566/blob'
SH

if ! grep -q '.pulumi-state-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-state-env.sh' >> /root/.bashrc
fi

cd /root/workspace/state-backends-azure

cat > package.json <<'JSON'
{
  "name": "state-backends-azure-lab",
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
name: state-backends-azure
runtime:
  name: nodejs
description: Explore Pulumi state and DIY backends with a miniblue Azure Blob container.
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
name: state-backends-azure
runtime:
  name: nodejs
description: Explore Pulumi state and DIY backends with a miniblue Azure Blob container.
backend:
  url: "azblob://pulumi-state?storage_account=pulumistate&protocol=http&domain=localhost:4566/blob"
YAML

npm install --no-audit --no-fund >/dev/null

touch /tmp/.setup-done
echo "State Backend Azure lab is ready in /root/workspace/state-backends-azure"
