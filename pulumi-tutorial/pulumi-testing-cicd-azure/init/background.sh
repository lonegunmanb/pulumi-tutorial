#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-testing-cicd-azure"
export SCENARIO_TITLE="测试驱动开发与 CI/CD：Azure / miniblue 版"
export PULUMI_CONFIG_PASSPHRASE=""
export SKIP_SAMPLE_PROJECT=1
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done
bash /root/setup-common.sh || true

export PATH="$HOME/.pulumi/bin:$PATH"
for line in 'export PULUMI_CONFIG_PASSPHRASE=""' 'export TS_NODE_TRANSPILE_ONLY=1' 'export NODE_OPTIONS=--max-old-space-size=512' 'export SSL_CERT_FILE=/root/.miniblue/cert.pem'; do
	grep -q "$line" /root/.bashrc 2>/dev/null || echo "$line" >> /root/.bashrc
done

apt-get install -y curl jq openssl ca-certificates >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true
if ! docker compose version >/dev/null 2>&1; then
	mkdir -p /usr/local/lib/docker/cli-plugins
	curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
		-o /usr/local/lib/docker/cli-plugins/docker-compose
	chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-39cc27a
    container_name: pulumi-testing-cicd-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

docker compose up -d >/dev/null 2>&1 || true
for attempt in $(seq 1 60); do
	if curl -sf http://localhost:4566/health >/dev/null 2>&1; then
		break
	fi
	if [ "$attempt" = "60" ]; then
		docker compose logs || true
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

cat > package.json <<'JSON'
{
  "name": "pulumi-testing-cicd-azure-lab",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "test": "npm run test:unit",
    "test:unit": "mocha -r ts-node/register test/unit.spec.ts",
    "test:integration": "mocha -r ts-node/register test/integration.spec.ts",
    "test:all": "npm run test:unit && npm run test:integration",
    "preview:ci": "pulumi stack select dev && pulumi preview --non-interactive"
  },
  "dependencies": {
    "@pulumi/azure": "^6.0.0",
    "@pulumi/pulumi": "^3.0.0"
  },
  "devDependencies": {
    "@types/mocha": "^10.0.0",
    "@types/node": "^20.0.0",
    "mocha": "^10.0.0",
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
name: pulumi-testing-cicd-azure
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: TDD and CI/CD lab for Azure resources against miniblue.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

const config = new pulumi.Config();
const prefix = config.get("prefix") ?? "testing";
const location = "eastus";

const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

export const resourceGroup = new azure.core.ResourceGroup("app-rg", {
  name: `${prefix}-app-rg`,
  location,
  tags: {
    environment: "dev",
  },
}, { provider: miniblue });

export const virtualNetwork = new azure.network.VirtualNetwork("app-vnet", {
  name: `${prefix}-app-vnet`,
  resourceGroupName: resourceGroup.name,
  location,
  addressSpaces: ["10.20.0.0/16"],
  subnets: [{ name: "app", addressPrefixes: ["10.20.1.0/24"] }],
  tags: {
    environment: "dev",
  },
}, { provider: miniblue });

export const resourceGroupName = resourceGroup.name;
export const virtualNetworkName = virtualNetwork.name;
TS

mkdir -p asserts
cat > asserts/unit.spec.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { strict as assert } from "node:assert";
import "mocha";

// 单元测试不会访问 miniblue 或 Azure。这里的 mock runtime 会接住 Pulumi 程序注册资源时传入的输入，
// 并返回测试需要的假 provider 输出。
pulumi.runtime.setMocks({
  newResource(args: pulumi.runtime.MockResourceArgs) {
    return {
      id: `${args.name}_id`,
      state: {
        ...args.inputs,
        // id 通常由 Azure provider 计算。这里手工合成一个简单值，
        // 让测试无需创建真实 Resource Group 也能读取它。
        id: `/subscriptions/00000000/resourceGroups/${args.inputs.name ?? args.name}`,
      },
    };
  },
  call(args: pulumi.runtime.MockCallArgs) {
    return args.inputs;
  },
}, "pulumi-testing-cicd-azure", "dev", false);

// 即使在单元测试里，资源属性仍然是 Output，所以断言前要先等待它 resolve。
function outputOf<T>(value: pulumi.Output<T>): Promise<T> {
  return new Promise((resolve) => value.apply(resolve));
}

describe("azure resource contract", () => {
  let infra: typeof import("../index");

  before(async () => {
    // 一定要先 setMocks，再导入 Pulumi 程序。导入 index.ts 会立即创建资源对象，
    // 所以 mock runtime 必须提前准备好。
    infra = await import("../index");
  });

  it("declares resource group ownership tags", async () => {
    // 这是红灯测试：初始的 index.ts 还没有这两个标签。
    const tags = await outputOf(infra.resourceGroup.tags);
    assert.equal(tags?.owner, "platform-team");
    assert.equal(tags?.managedBy, "pulumi");
  });

  it("uses the approved network range", async () => {
    // 快速单元测试也可以保护重要的网络形态约束。
    assert.deepEqual(await outputOf(infra.virtualNetwork.addressSpaces), ["10.20.0.0/16"]);
  });
});
TS

cat > asserts/fixed-index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

const config = new pulumi.Config();
const prefix = config.get("prefix") ?? "testing";
const location = "eastus";
const commonTags = {
  environment: "dev",
  owner: "platform-team",
  managedBy: "pulumi",
};

const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

export const resourceGroup = new azure.core.ResourceGroup("app-rg", {
  name: `${prefix}-app-rg`,
  location,
  tags: commonTags,
}, { provider: miniblue });

export const virtualNetwork = new azure.network.VirtualNetwork("app-vnet", {
  name: `${prefix}-app-vnet`,
  resourceGroupName: resourceGroup.name,
  location,
  addressSpaces: ["10.20.0.0/16"],
  subnets: [{ name: "app", addressPrefixes: ["10.20.1.0/24"] }],
  tags: commonTags,
}, { provider: miniblue });

export const resourceGroupName = resourceGroup.name;
export const virtualNetworkName = virtualNetwork.name;
TS

cat > asserts/integration.spec.ts <<'TS'
import * as automation from "@pulumi/pulumi/automation";
import { strict as assert } from "node:assert";
import "mocha";

type DeploymentResource = {
  type?: string;
  inputs?: {
    addressSpaces?: string[];
    tags?: Record<string, string>;
  };
};

describe("automation api integration", function () {
  this.timeout(240_000);

  const stackName = `it-${Date.now()}`;
  let stack: automation.Stack | undefined;

  after(async () => {
    if (!stack) {
      return;
    }

    await stack.destroy({ onOutput: console.info });
    await stack.workspace.removeStack(stackName);
  });

  it("deploys a temporary stack and validates state", async () => {
    stack = await automation.LocalWorkspace.createOrSelectStack({
      stackName,
      workDir: process.cwd(),
    }, {
      envVars: {
        PULUMI_CONFIG_PASSPHRASE: "",
        TS_NODE_TRANSPILE_ONLY: "1",
        NODE_OPTIONS: "--max-old-space-size=512",
        SSL_CERT_FILE: "/root/.miniblue/cert.pem",
        ARM_CLIENT_ID: "miniblue",
        ARM_CLIENT_SECRET: "miniblue",
        ARM_SUBSCRIPTION_ID: "00000000-0000-0000-0000-000000000000",
        ARM_TENANT_ID: "00000000-0000-0000-0000-000000000001",
      },
    });

    await stack.setConfig("prefix", { value: "it" });
    await stack.preview({ onOutput: console.info });

    const result = await stack.up({ onOutput: console.info });
    assert.equal(result.outputs.resourceGroupName.value, "it-app-rg");

    const exported = await stack.exportStack();
    const resources = exported.deployment.resources as DeploymentResource[];
    const resourceGroup = resources.find((resource) => resource.type === "azure:core/resourceGroup:ResourceGroup");
    const virtualNetwork = resources.find((resource) => resource.type === "azure:network/virtualNetwork:VirtualNetwork");

    assert.ok(resourceGroup, "expected a Resource Group resource in the deployment state");
    assert.ok(virtualNetwork, "expected a Virtual Network resource in the deployment state");
    assert.equal(resourceGroup?.inputs?.tags?.owner, "platform-team");
    assert.deepEqual(virtualNetwork?.inputs?.addressSpaces, ["10.20.0.0/16"]);
  });
});
TS

cat > asserts/pulumi-preview.yml <<'YAML'
name: Pulumi preview

on:
  pull_request:

permissions:
  contents: read

concurrency:
  group: pulumi-pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  preview:
    runs-on: ubuntu-latest
    env:
      PULUMI_CONFIG_PASSPHRASE: ""
      TS_NODE_TRANSPILE_ONLY: "1"
      NODE_OPTIONS: --max-old-space-size=512
      ARM_CLIENT_ID: miniblue
      ARM_CLIENT_SECRET: miniblue
      ARM_SUBSCRIPTION_ID: 00000000-0000-0000-0000-000000000000
      ARM_TENANT_ID: 00000000-0000-0000-0000-000000000001
    steps:
      - uses: actions/checkout@v4
        with:
          clean: false
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm install --no-audit --no-fund
      - run: npm run test:unit
      - name: Ensure miniblue is ready
        run: |
          if curl -sf http://localhost:4566/health; then
            exit 0
          fi
          docker compose up -d
          for attempt in $(seq 1 60); do
            curl -sf http://localhost:4566/health && exit 0
            sleep 2
          done
          exit 1
      - name: Trust miniblue metadata certificate
        run: |
          for attempt in $(seq 1 60); do
            curl -sk https://localhost:4567/metadata/endpoints?api-version=2019-05-01 && break
            sleep 2
          done
          openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null | openssl x509 > miniblue.crt
          sudo cp miniblue.crt /usr/local/share/ca-certificates/miniblue.crt
          sudo update-ca-certificates
      - uses: pulumi/setup-pulumi@v2
      - run: pulumi login --local
      - run: pulumi stack select dev || pulumi stack init dev
      - run: pulumi config set prefix ci
      - uses: pulumi/actions@v7
        with:
          command: preview
          stack-name: dev
          work-dir: .
YAML

npm install --no-audit --no-fund >/dev/null
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null
pulumi config set prefix testing >/dev/null

cat > .gitignore <<'GITIGNORE'
node_modules/
.github/
GITIGNORE
git init >/dev/null 2>&1 || true
git config user.email "learner@example.com" >/dev/null 2>&1 || true
git config user.name "Pulumi Tutorial" >/dev/null 2>&1 || true
git add package.json package-lock.json tsconfig.json Pulumi.yaml index.ts docker-compose.yml asserts .gitignore >/dev/null 2>&1 || true
git commit -m "Initial lab workspace" >/dev/null 2>&1 || true

if ! command -v act >/dev/null 2>&1; then
	curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin >/dev/null
fi

touch /tmp/.setup-done
