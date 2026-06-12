#!/usr/bin/env bash
set -o pipefail

SCENARIO_ID="${SCENARIO_ID:-pulumi-lab}"
SCENARIO_TITLE="${SCENARIO_TITLE:-Pulumi Lab}"
WORKSPACE="/root/workspace"

export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q '.pulumi/bin' /root/.bashrc 2>/dev/null; then
  echo 'export PATH="$HOME/.pulumi/bin:$PATH"' >> /root/.bashrc
fi

# 本教程统一使用空口令的本地后端，写入 .bashrc 后新开终端无需再显式配置。
export PULUMI_CONFIG_PASSPHRASE="${PULUMI_CONFIG_PASSPHRASE:-}"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi

apt-get update >/dev/null
apt-get install -y curl ca-certificates git jq >/dev/null

if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)" -lt 18 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null
  apt-get install -y nodejs >/dev/null
fi

if ! command -v pulumi >/dev/null 2>&1; then
  curl -fsSL https://get.pulumi.com | sh >/dev/null
fi

mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

pulumi login --local >/dev/null 2>&1 || true

if [ "${SKIP_SAMPLE_PROJECT:-0}" = "1" ]; then
  echo "Pulumi common tools are ready in $WORKSPACE"
  exit 0
fi

cat > package.json <<'JSON'
{
  "name": "pulumi-killercoda-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@pulumi/pulumi": "^3.0.0",
    "@pulumi/random": "^4.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  }
}
JSON

cat > Pulumi.yaml <<YAML
name: ${SCENARIO_ID}
runtime:
  name: nodejs
description: ${SCENARIO_TITLE}
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";

const config = new pulumi.Config();
const prefix = config.get("prefix") ?? "pulumi";

const pet = new random.RandomPet("lab-name", {
  prefix,
  length: 2,
});

export const resourceName = pet.id;
export const message = pulumi.interpolate`Hello from ${pet.id}`;
TS

if [ ! -d node_modules ]; then
  npm install --no-audit --no-fund >/dev/null
fi

pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null
pulumi config set prefix "$SCENARIO_ID" >/dev/null

echo "Pulumi lab is ready in $WORKSPACE"