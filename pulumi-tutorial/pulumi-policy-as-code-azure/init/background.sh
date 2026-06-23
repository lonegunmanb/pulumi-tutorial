#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-policy-as-code-azure"
export SCENARIO_TITLE="Policy as Code（Azure / miniblue）"
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

mkdir -p /root/workspace/policy-as-code-azure/app/variants /root/workspace/policy-as-code-azure/policy-pack
cd /root/workspace/policy-as-code-azure

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-39cc27a
    container_name: pulumi-policy-miniblue
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

cat > /root/.pulumi-policy-env.sh <<'SH'
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
SH

if ! grep -q '.pulumi-policy-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-policy-env.sh' >> /root/.bashrc
fi

cd /root/workspace/policy-as-code-azure/app

cat > package.json <<'JSON'
{
  "name": "policy-as-code-azure-app",
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
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: policy-as-code-azure
runtime:
  name: nodejs
description: Azure policy-as-code lab against miniblue.
YAML

cat > variants/bad.ts <<'TS'
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

const group = new azure.core.ResourceGroup("app-rg", {
  name: "tmp-policy-rg",
  location: "westus2",
  tags: {
    environment: "dev",
  },
}, { provider: miniblue });

export const resourceGroupName = group.name;
TS

cat > variants/good.ts <<'TS'
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

const group = new azure.core.ResourceGroup("app-rg", {
  name: "policy-lab-dev-rg",
  location: "eastus",
  tags: {
    environment: "dev",
    owner: "platform-team",
    managedBy: "pulumi",
  },
}, { provider: miniblue });

export const resourceGroupName = group.name;
TS

cp variants/bad.ts index.ts

npm install --no-audit --no-fund >/dev/null

cd /root/workspace/policy-as-code-azure/policy-pack

cat > package.json <<'JSON'
{
  "name": "policy-as-code-azure-pack",
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
description: Local Azure policy pack for location and tagging checks.
author: Pulumi Tutorial
YAML

cat > index.ts <<'TS'
import { PolicyPack } from "@pulumi/policy";
import type { ResourceValidationPolicy, StackValidationPolicy } from "@pulumi/policy";

const resourceGroupType = "azure:core/resourceGroup:ResourceGroup";

const requireResourceGroupTags: ResourceValidationPolicy = {
  name: "azure-resource-group-required-tags",
  description: "Resource groups must declare owner and managedBy tags.",
  enforcementLevel: "mandatory",
  validateResource: (args, reportViolation) => {
    if (args.type !== resourceGroupType) {
      return;
    }
    const tags = (args.props.tags || {}) as Record<string, string>;
    if (!tags.owner) {
      reportViolation("Resource Group must include an owner tag.");
    }
    if (tags.managedBy !== "pulumi") {
      reportViolation("Resource Group must set managedBy to pulumi.");
    }
  },
};

const approvedLocation: ResourceValidationPolicy = {
  name: "azure-resource-group-approved-location",
  description: "Resource groups in this tutorial must use eastus.",
  enforcementLevel: "mandatory",
  validateResource: (args, reportViolation) => {
    if (args.type !== resourceGroupType) {
      return;
    }
    if (String(args.props.location || "").toLowerCase() !== "eastus") {
      reportViolation(`Resource Group must use eastus. Current value: ${args.props.location}`);
    }
  },
};

const resourceGroupNamePrefix: ResourceValidationPolicy = {
  name: "azure-resource-group-policy-lab-prefix",
  description: "Resource groups should use the policy-lab prefix in this tutorial.",
  enforcementLevel: "advisory",
  validateResource: (args, reportViolation) => {
    if (args.type !== resourceGroupType) {
      return;
    }
    const name = String(args.props.name || args.name || "");
    if (!name.startsWith("policy-lab-")) {
      reportViolation(`Resource Group should start with policy-lab-. Current value: ${name}`);
    }
  },
};

const maxResourceGroups: StackValidationPolicy = {
  name: "azure-resource-group-maximum-count",
  description: "Stacks in this tutorial may contain at most two resource groups.",
  enforcementLevel: "mandatory",
  validateStack: (args, reportViolation) => {
    const count = args.resources.filter(resource => resource.type === resourceGroupType).length;
    if (count > 2) {
      reportViolation(`Stack contains ${count} resource groups; maximum allowed is 2.`);
    }
  },
};

new PolicyPack("policy-as-code-azure", {
  policies: [requireResourceGroupTags, approvedLocation, resourceGroupNamePrefix, maxResourceGroups],
});
TS

npm install --no-audit --no-fund >/dev/null

pulumi login --local >/dev/null

touch /tmp/.setup-done
echo "Policy as Code Azure lab is ready in /root/workspace/policy-as-code-azure"