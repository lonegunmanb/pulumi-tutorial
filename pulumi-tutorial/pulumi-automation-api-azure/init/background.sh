#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-automation-api-azure"
export SCENARIO_TITLE="Automation API：Azure / miniblue 版"
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

apt-get install -y jq openssl >/dev/null 2>&1 || true
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
    image: ghcr.io/lonegunmanb/miniblue:sha-6d934ae
    container_name: pulumi-automation-api-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-automation-api-azure-lab",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "automation": "ts-node --transpile-only automation.ts",
    "server": "ts-node --transpile-only server.ts"
  },
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
name: pulumi-automation-api-azure
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Automation API local program for an Azure network environment on miniblue.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

interface SubnetSettings {
  name: string;
  addressPrefix: string;
}

interface EnvironmentSettings {
  namePrefix: string;
  location: string;
  owner: string;
  addressSpace: string;
  subnets: SubnetSettings[];
  tags: Record<string, string>;
}

const stack = pulumi.getStack();
const project = pulumi.getProject();
const config = new pulumi.Config();
const settings = config.requireObject<EnvironmentSettings>("settings");
const releaseToken = config.requireSecret("releaseToken");

const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

const commonTags = {
  ...settings.tags,
  owner: settings.owner,
  project,
  environment: stack,
  managedBy: "pulumi",
};

const resourceGroup = new azure.core.ResourceGroup("workload-rg", {
  name: `${settings.namePrefix}-${stack}-rg`,
  location: settings.location,
  tags: commonTags,
}, { provider: miniblue });

const virtualNetwork = new azure.network.VirtualNetwork("workload-vnet", {
  name: `${settings.namePrefix}-${stack}-vnet`,
  resourceGroupName: resourceGroup.name,
  location: settings.location,
  addressSpaces: [settings.addressSpace],
  subnets: settings.subnets.map((subnet) => ({
    name: subnet.name,
    addressPrefixes: [subnet.addressPrefix],
  })),
  tags: commonTags,
}, { provider: miniblue });

export const environment = stack;
export const resourceGroupName = resourceGroup.name;
export const virtualNetworkName = virtualNetwork.name;
export const location = settings.location;
export const subnetNames = settings.subnets.map((subnet) => subnet.name);
export const networkPlan = pulumi.jsonStringify({
  addressSpace: settings.addressSpace,
  subnets: settings.subnets,
  virtualNetworkId: virtualNetwork.id,
});
export const tokenHint = releaseToken.apply((value) => `token length: ${value.length}`);
TS

cat > automation.ts <<'TS'
import * as automation from "@pulumi/pulumi/automation";

export type Action = "preview" | "up" | "refresh" | "destroy" | "outputs";

const projectName = "pulumi-automation-api-azure";
const pluginVersion = "v6.0.0";

interface SubnetSettings {
  name: string;
  addressPrefix: string;
}

interface EnvironmentSettings {
  namePrefix: string;
  location: string;
  owner: string;
  addressSpace: string;
  subnets: SubnetSettings[];
  tags: Record<string, string>;
}

const profiles: Record<string, EnvironmentSettings> = {
  dev: {
    namePrefix: "autoaz-dev",
    location: "eastus",
    owner: "platform-dev",
    addressSpace: "10.20.0.0/16",
    subnets: [
      { name: "app", addressPrefix: "10.20.1.0/24" },
    ],
    tags: {
      costCenter: "lab-dev",
      service: "network-service",
    },
  },
  svc1: {
    namePrefix: "autoaz-svc1",
    location: "eastus",
    owner: "platform-svc1",
    addressSpace: "10.40.0.0/16",
    subnets: [
      { name: "app", addressPrefix: "10.40.1.0/24" },
      { name: "data", addressPrefix: "10.40.2.0/24" },
    ],
    tags: {
      costCenter: "lab-svc1",
      service: "network-service",
    },
  },
};

function safeStackPart(stackName: string): string {
  return stackName.toLowerCase().replace(/[^a-z0-9-]/g, "-").slice(0, 30) || "env";
}

function profileFor(stackName: string): EnvironmentSettings {
  if (profiles[stackName]) {
    return profiles[stackName];
  }

  const safe = safeStackPart(stackName);
  return {
    namePrefix: `autoaz-${safe}`,
    location: "eastus",
    owner: "platform-self-service",
    addressSpace: "10.60.0.0/16",
    subnets: [
      { name: "app", addressPrefix: "10.60.1.0/24" },
    ],
    tags: {
      costCenter: "lab-dynamic",
      service: "network-service",
    },
  };
}

function envVars(): Record<string, string> {
  return {
    PULUMI_CONFIG_PASSPHRASE: process.env.PULUMI_CONFIG_PASSPHRASE ?? "",
    TS_NODE_TRANSPILE_ONLY: "1",
    NODE_OPTIONS: process.env.NODE_OPTIONS ?? "--max-old-space-size=512",
    ARM_CLIENT_ID: "miniblue",
    ARM_CLIENT_SECRET: "miniblue",
    ARM_SUBSCRIPTION_ID: "00000000-0000-0000-0000-000000000000",
    ARM_TENANT_ID: "00000000-0000-0000-0000-000000000001",
  };
}

function logEvent(event: any): void {
  if (event.resourcePreEvent) {
    const metadata = event.resourcePreEvent.metadata;
    console.log(`[event] ${metadata.op} ${metadata.type} ${metadata.name}`);
  }
  if (event.diagnosticEvent?.severity === "error") {
    console.error(`[diagnostic] ${event.diagnosticEvent.message}`);
  }
}

function operationOptions() {
  return {
    onOutput: (line: string) => console.log(line),
    onEvent: logEvent,
  };
}

function simplifyOutputs(outputs: automation.OutputMap | undefined): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(outputs ?? {})) {
    result[key] = value.secret ? "[secret]" : value.value;
  }
  return result;
}

async function selectStack(stackName: string): Promise<automation.Stack> {
  const stack = await automation.LocalWorkspace.createOrSelectStack(
    { stackName, workDir: process.cwd() },
    { envVars: envVars() },
  );

  await stack.workspace.installPlugin("azure", pluginVersion);
  await configureStack(stack, stackName);
  return stack;
}

async function configureStack(stack: automation.Stack, stackName: string): Promise<void> {
  const settings = profileFor(stackName);
  await stack.setConfig("azure:location", { value: settings.location });
  await stack.setConfig(`${projectName}:settings`, { value: JSON.stringify(settings) });
  await stack.setConfig(`${projectName}:releaseToken`, {
    value: `token-${safeStackPart(stackName)}-local-only`,
    secret: true,
  });
}

export async function run(action: Action, stackName = "dev"): Promise<Record<string, unknown>> {
  const stack = await selectStack(stackName);
  const opts = operationOptions();

  if (action === "preview") {
    const result: any = await stack.preview(opts);
    return { action, stackName, changeSummary: result.changeSummary };
  }

  if (action === "up") {
    const result: any = await stack.up(opts);
    return { action, stackName, summary: result.summary, outputs: simplifyOutputs(result.outputs) };
  }

  if (action === "refresh") {
    const result: any = await stack.refresh(opts);
    return { action, stackName, summary: result.summary };
  }

  if (action === "destroy") {
    const result: any = await stack.destroy(opts);
    return { action, stackName, summary: result.summary };
  }

  if (action === "outputs") {
    return { action, stackName, outputs: simplifyOutputs(await stack.outputs()) };
  }

  throw new Error(`Unsupported action: ${action}`);
}

async function main(): Promise<void> {
  const action = (process.argv[2] ?? "preview") as Action;
  const stackName = process.argv[3] ?? "dev";
  const result = await run(action, stackName);
  console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  });
}
TS

cat > server.ts <<'TS'
import { createServer, ServerResponse } from "http";
import { Action, run } from "./automation";

function send(res: ServerResponse, statusCode: number, body: unknown): void {
  res.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body, null, 2));
}

function route(method: string, pathname: string): { action: Action; stackName: string } | undefined {
  const match = pathname.match(/^\/stacks\/([A-Za-z0-9._-]+)(?:\/(preview|refresh|outputs))?$/);
  if (!match) {
    return undefined;
  }

  const stackName = match[1];
  const suffix = match[2];

  if (method === "POST" && suffix === "preview") return { action: "preview", stackName };
  if (method === "POST" && suffix === "refresh") return { action: "refresh", stackName };
  if (method === "POST" && !suffix) return { action: "up", stackName };
  if (method === "GET" && suffix === "outputs") return { action: "outputs", stackName };
  if (method === "DELETE" && !suffix) return { action: "destroy", stackName };
  return undefined;
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);
  const request = route(req.method ?? "GET", url.pathname);

  if (!request) {
    send(res, 404, { error: "not found" });
    return;
  }

  try {
    const result = await run(request.action, request.stackName);
    send(res, 200, result);
  } catch (error) {
    send(res, 500, { error: error instanceof Error ? error.message : String(error) });
  }
});

server.listen(3000, "0.0.0.0", () => {
  console.log("Automation API wrapper is listening on http://localhost:3000");
});
TS

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true

pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
pulumi config set azure:location eastus >/dev/null 2>&1 || true
pulumi config set pulumi-automation-api-azure:settings '{"namePrefix":"autoaz-dev","location":"eastus","owner":"platform-dev","addressSpace":"10.20.0.0/16","subnets":[{"name":"app","addressPrefix":"10.20.1.0/24"}],"tags":{"costCenter":"lab-dev","service":"network-service"}}' >/dev/null 2>&1 || true
pulumi config set pulumi-automation-api-azure:releaseToken cli-token-local-only --secret >/dev/null 2>&1 || true

git init >/dev/null 2>&1 || true
git config user.email pulumi-lab@example.com >/dev/null 2>&1 || true
git config user.name "Pulumi Lab" >/dev/null 2>&1 || true
git add Pulumi.yaml Pulumi.dev.yaml index.ts automation.ts server.ts package.json package-lock.json tsconfig.json docker-compose.yml >/dev/null 2>&1 || true
git commit -m "Initial Automation API Azure lab" >/dev/null 2>&1 || true

docker pull ghcr.io/lonegunmanb/miniblue:sha-6d934ae >/dev/null 2>&1 || true
if ! docker compose up -d >/dev/null 2>&1; then
  echo "docker compose up -d 执行失败，将继续输出容器状态用于排查。"
  docker compose ps || true
fi

miniblue_ready=0
for _ in $(seq 1 120); do
  if curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" >/dev/null 2>&1; then
    miniblue_ready=1
    break
  fi
  sleep 2
done

if [ "$miniblue_ready" = "1" ]; then
  openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null \
    | openssl x509 > /usr/local/share/ca-certificates/miniblue.crt 2>/dev/null || true
  update-ca-certificates >/dev/null 2>&1 || true
  touch /tmp/.setup-done
  echo "Azure / miniblue Automation API lab is ready in /root/workspace (miniblue healthy)"
else
  echo "miniblue 健康检查未通过，未创建 /tmp/.setup-done。可执行 'docker compose ps' 与 'docker compose logs miniblue' 排查。"
  curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" || true
  docker compose ps || true
  docker compose logs --tail=80 miniblue || true
fi