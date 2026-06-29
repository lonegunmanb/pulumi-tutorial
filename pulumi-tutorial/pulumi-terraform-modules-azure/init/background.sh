#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-terraform-modules-azure"
export SCENARIO_TITLE="使用 Terraform Module：Azure / MiniBlue 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
export ARM_CLIENT_ID=miniblue
export ARM_CLIENT_SECRET=miniblue
export ARM_TENANT_ID=00000000-0000-0000-0000-000000000001
export ARM_SUBSCRIPTION_ID=00000000-0000-0000-0000-000000000000
export ARM_METADATA_HOSTNAME=localhost:4567
export ARM_USE_CLI=false
export SSL_CERT_FILE=/root/.miniblue/cert.pem

rm -f /tmp/.setup-done

if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null || true
  chmod 600 /swapfile 2>/dev/null || true
  mkswap /swapfile >/dev/null 2>&1 || true
  swapon /swapfile >/dev/null 2>&1 || true
fi

bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

cat > /root/.pulumi-terraform-modules-azure-env.sh <<'SH'
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
export ARM_CLIENT_ID=miniblue
export ARM_CLIENT_SECRET=miniblue
export ARM_TENANT_ID=00000000-0000-0000-0000-000000000001
export ARM_SUBSCRIPTION_ID=00000000-0000-0000-0000-000000000000
export ARM_METADATA_HOSTNAME=localhost:4567
export ARM_USE_CLI=false
export SSL_CERT_FILE=/root/.miniblue/cert.pem
SH
grep -q '.pulumi-terraform-modules-azure-env.sh' /root/.bashrc 2>/dev/null || echo 'source /root/.pulumi-terraform-modules-azure-env.sh' >> /root/.bashrc

apt-get install -y curl jq openssl ca-certificates >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true
if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/workspace/terraform-modules-azure/variants /root/.miniblue
cd /root/workspace/terraform-modules-azure

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-39cc27a
    container_name: pulumi-terraform-modules-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

docker compose up -d >/dev/null 2>&1 || true
for attempt in $(seq 1 90); do
  if curl -sf http://localhost:4566/health >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" = "90" ]; then
    docker compose logs || true
    exit 1
  fi
  sleep 2
done

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

SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
RESOURCE_GROUP_NAME="rg-tfmod-vnet"
RESOURCE_GROUP_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}"

curl -s -X PUT "http://localhost:4566/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RESOURCE_GROUP_NAME}" \
  -H 'Content-Type: application/json' \
  -d '{"location":"eastus","tags":{"managedBy":"miniblue-init","purpose":"terraform-module-lab"}}' >/dev/null || true

cat > package.json <<'JSON'
{
  "name": "terraform-modules-azure-lab",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
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
name: terraform-modules-azure-lab
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Use Azure AVM Virtual Network Terraform Module from Pulumi against MiniBlue.
YAML

cat > variants/base.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as avmvnet from "@pulumi/avmvnet";

const stack = pulumi.getStack();
const location = "eastus";
const parentId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tfmod-vnet";

const network = new avmvnet.Module("tutorial-vnet", {
  location,
  parent_id: parentId,
  name: `vnet-tfmod-${stack}`,
  address_space: ["10.40.0.0/16"],
  enable_telemetry: false,
  subnets: {
    web: {
      name: "snet-web",
      address_prefixes: ["10.40.1.0/24"],
    },
    app: {
      name: "snet-app",
      address_prefixes: ["10.40.2.0/24"],
    },
  },
  tags: {
    environment: stack,
    managedBy: "pulumi",
    purpose: "terraform-module-lab",
  },
});

export const resourceGroupId = parentId;
export const virtualNetworkId = network.resource_id;
export const virtualNetworkName = network.name;
export const addressSpaces = network.address_spaces;
export const subnetMap = network.subnets;
TS

cat > variants/expanded.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as avmvnet from "@pulumi/avmvnet";

const stack = pulumi.getStack();
const location = "eastus";
const parentId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tfmod-vnet";

const network = new avmvnet.Module("tutorial-vnet", {
  location,
  parent_id: parentId,
  name: `vnet-tfmod-${stack}`,
  address_space: ["10.40.0.0/16"],
  enable_telemetry: false,
  subnets: {
    web: {
      name: "snet-web",
      address_prefixes: ["10.40.1.0/24"],
    },
    app: {
      name: "snet-app",
      address_prefixes: ["10.40.2.0/24"],
    },
    data: {
      name: "snet-data",
      address_prefixes: ["10.40.3.0/24"],
    },
  },
  tags: {
    environment: stack,
    managedBy: "pulumi",
    purpose: "terraform-module-lab-expanded",
  },
});

export const resourceGroupId = parentId;
export const virtualNetworkId = network.resource_id;
export const virtualNetworkName = network.name;
export const addressSpaces = network.address_spaces;
export const subnetMap = network.subnets;
TS

cp variants/base.ts index.ts
npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Terraform Module Azure lab is ready in /root/workspace/terraform-modules-azure"