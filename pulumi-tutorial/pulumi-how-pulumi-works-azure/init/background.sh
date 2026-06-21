#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-how-pulumi-works-azure"
export SCENARIO_TITLE="Pulumi 是如何工作的：Azure / miniblue 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done
mkdir -p /root/workspace

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

apt-get install -y jq curl openssl >/dev/null 2>&1 || true
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
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-0e58f75
    container_name: pulumi-how-works-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-how-pulumi-works-azure-lab",
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
name: pulumi-how-pulumi-works-azure
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Observe how Pulumi registers, diffs and updates Azure resources against miniblue.
YAML

read -r -d '' PROVIDER_TS <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

const location = "eastus";
TS

cat > variants/base.ts <<TS
${PROVIDER_TS}

const mediaGroup = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { owner: "media-team", phase: "initial" },
}, { provider: miniblue });

const contentGroup = new azure.core.ResourceGroup("content-rg", {
  location,
  tags: { owner: "content-team", phase: "initial" },
}, { provider: miniblue });

export const mediaPhysicalName = mediaGroup.name;
export const contentPhysicalName = contentGroup.name;
export const contentPhysicalId = contentGroup.id;
export const operationHint = pulumi
  .all([mediaGroup.name, contentGroup.name])
  .apply(([mediaName, contentName]) => "Engine registered " + mediaName + " and " + contentName + ", then the Azure provider called miniblue.");
TS

cat > variants/step3-update.ts <<TS
${PROVIDER_TS}

const mediaGroup = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { owner: "media-team", phase: "tagged" },
}, { provider: miniblue });

const contentGroup = new azure.core.ResourceGroup("content-rg", {
  location,
  tags: { owner: "content-team", phase: "initial" },
}, { provider: miniblue });

export const mediaPhysicalName = mediaGroup.name;
export const contentPhysicalName = contentGroup.name;
export const contentPhysicalId = contentGroup.id;
TS

cat > variants/step4-rename.ts <<TS
${PROVIDER_TS}

const mediaGroup = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { owner: "media-team", phase: "tagged" },
}, { provider: miniblue });

const appGroup = new azure.core.ResourceGroup("app-rg", {
  location,
  tags: { owner: "content-team", phase: "renamed" },
}, { provider: miniblue });

export const mediaPhysicalName = mediaGroup.name;
export const appPhysicalName = appGroup.name;
TS

cat > variants/step5-delete.ts <<TS
${PROVIDER_TS}

const mediaGroup = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { owner: "media-team", phase: "tagged" },
}, { provider: miniblue });

export const mediaPhysicalName = mediaGroup.name;
TS

cp variants/base.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ghcr.io/lonegunmanb/miniblue:sha-0e58f75 >/dev/null 2>&1 || true

# 启动 miniblue 并等待 metadata 端口就绪。
docker compose up -d >/dev/null 2>&1 || true
for attempt in $(seq 1 60); do
  if curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" >/dev/null 2>&1; then
    echo "miniblue metadata 已就绪。"
    break
  fi
  sleep 2
done

# 导出 miniblue 证书并加入系统信任库（azurerm provider 是 Go 二进制，使用系统 CA）。
openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 > /usr/local/share/ca-certificates/miniblue.crt 2>/dev/null || true
update-ca-certificates >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "[$(date +%Y-%m-%dT%H:%M:%S)] Azure / miniblue how-pulumi-works lab is ready in /root/workspace"