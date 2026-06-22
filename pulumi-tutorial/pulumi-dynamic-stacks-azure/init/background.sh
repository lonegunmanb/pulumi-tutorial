#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-dynamic-stacks-azure"
export SCENARIO_TITLE="动态 Stack 配置：Azure / miniblue 版"
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
    container_name: pulumi-dynamic-stacks-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-dynamic-stacks-azure-lab",
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
name: pulumi-dynamic-stacks-azure
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Drive Azure network resources from dev/prod stack configuration against miniblue.
config:
  pulumi-dynamic-stacks-azure:defaultOwner: platform-team
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

interface SubnetSettings {
  name: string;
  addressPrefix: string;
  private: boolean;
}

interface EnvironmentSettings {
  namePrefix: string;
  location: string;
  addressSpace: string;
  enablePrivateSubnet: boolean;
  tags: Record<string, string>;
  subnets: SubnetSettings[];
}

const stack = pulumi.getStack();
const project = pulumi.getProject();
const config = new pulumi.Config();
const defaultOwner = config.require("defaultOwner");
const settings = config.requireObject<EnvironmentSettings>("settings");
const operationsToken = config.requireSecret("operationsToken");

const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  skipProviderRegistration: true,
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
  environment: "public",
});

const commonTags = {
  owner: defaultOwner,
  ...settings.tags,
  project,
  environment: stack,
  managedBy: "pulumi",
};

const resourceGroup = new azure.core.ResourceGroup("workload-rg", {
  name: `${settings.namePrefix}-${stack}-rg`,
  location: settings.location,
  tags: commonTags,
}, { provider: miniblue });

const activeSubnets = settings.subnets.filter((subnet) => settings.enablePrivateSubnet || !subnet.private);
const privateSubnets = activeSubnets.filter((subnet) => subnet.private);

let privateNsg: azure.network.NetworkSecurityGroup | undefined;
if (settings.enablePrivateSubnet && privateSubnets.length > 0) {
  privateNsg = new azure.network.NetworkSecurityGroup("private-nsg", {
    name: `${settings.namePrefix}-${stack}-private-nsg`,
    resourceGroupName: resourceGroup.name,
    location: settings.location,
    tags: {
      ...commonTags,
      role: "private-subnet-guard",
    },
  }, { provider: miniblue });
}

const inlineSubnets = activeSubnets.map((subnet) => {
  const base: any = {
    name: subnet.name,
    addressPrefixes: [subnet.addressPrefix],
  };
  if (subnet.private && privateNsg) {
    return { ...base, securityGroup: privateNsg.id };
  }
  return base;
});

const virtualNetwork = new azure.network.VirtualNetwork("app-vnet", {
  name: `${settings.namePrefix}-${stack}-vnet`,
  resourceGroupName: resourceGroup.name,
  location: settings.location,
  addressSpaces: [settings.addressSpace],
  subnets: inlineSubnets,
  tags: commonTags,
}, { provider: miniblue });

const privateNsgName: pulumi.Output<string> = privateNsg ? privateNsg.name : pulumi.output("disabled");

export const environment = stack;
export const location = settings.location;
export const resourceGroupName = resourceGroup.name;
export const virtualNetworkName = virtualNetwork.name;
export const subnetNames = activeSubnets.map((subnet) => subnet.name);
export const privateSubnetEnabled = settings.enablePrivateSubnet;
export const privateNetworkSecurityGroup = privateNsgName;
export const networkPlan = pulumi.jsonStringify({
  stack,
  addressSpace: settings.addressSpace,
  activeSubnets,
  virtualNetworkId: virtualNetwork.id,
});
export const tokenHint = operationsToken.apply((value) => `token length: ${value.length}`);
TS

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true

pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
pulumi config set --path settings.namePrefix dynaz >/dev/null 2>&1 || true
pulumi config set --path settings.location eastus >/dev/null 2>&1 || true
pulumi config set --path settings.addressSpace 10.10.0.0/16 >/dev/null 2>&1 || true
pulumi config set --path settings.enablePrivateSubnet false >/dev/null 2>&1 || true
pulumi config set --path settings.tags.owner platform-dev >/dev/null 2>&1 || true
pulumi config set --path settings.tags.costCenter lab-dev >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[0].name app >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[0].addressPrefix 10.10.1.0/24 >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[0].private false >/dev/null 2>&1 || true
pulumi config set operationsToken dev-token-azure --secret >/dev/null 2>&1 || true

pulumi stack select prod >/dev/null 2>&1 || pulumi stack init prod >/dev/null 2>&1 || true
pulumi config set --path settings.namePrefix dynaz >/dev/null 2>&1 || true
pulumi config set --path settings.location eastus >/dev/null 2>&1 || true
pulumi config set --path settings.addressSpace 10.30.0.0/16 >/dev/null 2>&1 || true
pulumi config set --path settings.enablePrivateSubnet true >/dev/null 2>&1 || true
pulumi config set --path settings.tags.owner platform-prod >/dev/null 2>&1 || true
pulumi config set --path settings.tags.costCenter lab-prod >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[0].name app >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[0].addressPrefix 10.30.1.0/24 >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[0].private false >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[1].name services >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[1].addressPrefix 10.30.2.0/24 >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[1].private false >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[2].name data >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[2].addressPrefix 10.30.3.0/24 >/dev/null 2>&1 || true
pulumi config set --path settings.subnets[2].private true >/dev/null 2>&1 || true
pulumi config set operationsToken prod-token-azure --secret >/dev/null 2>&1 || true

pulumi stack select dev >/dev/null 2>&1 || true
mkdir -p backups

git init >/dev/null 2>&1 || true
git config user.email pulumi-lab@example.com >/dev/null 2>&1 || true
git config user.name "Pulumi Lab" >/dev/null 2>&1 || true
git add Pulumi.yaml Pulumi.dev.yaml Pulumi.prod.yaml index.ts package.json tsconfig.json docker-compose.yml >/dev/null 2>&1 || true
git commit -m "Initial dynamic Azure network config lab" >/dev/null 2>&1 || true

docker pull ghcr.io/lonegunmanb/miniblue:sha-6d934ae >/dev/null 2>&1 || true
docker compose up -d >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" >/dev/null 2>&1 && break
  sleep 2
done

openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 > /usr/local/share/ca-certificates/miniblue.crt 2>/dev/null || true
update-ca-certificates >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Azure / miniblue dynamic stacks lab is ready in /root/workspace"
