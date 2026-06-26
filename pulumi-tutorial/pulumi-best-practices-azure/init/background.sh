#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-best-practices-azure"
export SCENARIO_TITLE="最佳实践：Azure / miniblue DB for PostgreSQL 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done

bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

apt-get install -y jq openssl >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

cat > /root/.pulumi-best-practices-azure-env.sh <<'SH'
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
export SSL_CERT_FILE=/root/.miniblue/cert.pem
SH

if ! grep -q '.pulumi-best-practices-azure-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-best-practices-azure-env.sh' >> /root/.bashrc
fi

mkdir -p /root/workspace/best-practices-azure/platform \
  /root/workspace/best-practices-azure/workload/src \
  /root/workspace/best-practices-azure/workload/variants \
  /root/workspace/best-practices-azure/policy-pack \
  /root/.miniblue

cd /root/workspace/best-practices-azure

cat > docker-compose.yml <<'YAML'
services:
  postgres:
    image: postgres:16-alpine
    container_name: pulumi-best-practices-miniblue-postgres
    ports:
      - "15433:5432"
    environment:
      POSTGRES_USER: miniblue
      POSTGRES_PASSWORD: miniblue
      POSTGRES_DB: miniblue
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U miniblue -d miniblue"]
      interval: 2s
      timeout: 5s
      retries: 30

  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-39cc27a
    container_name: pulumi-best-practices-miniblue
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "4566:4566"
      - "4567:4567"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      LOG_LEVEL: info
      POSTGRES_URL: postgres://miniblue:miniblue@postgres:5432/miniblue?sslmode=disable
YAML

docker compose up -d

for attempt in $(seq 1 90); do
  if curl -sf http://localhost:4566/health >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" = "90" ]; then
    docker compose logs
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

cd /root/workspace/best-practices-azure/platform

cat > package.json <<'JSON'
{
  "name": "best-practices-azure-platform",
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
name: best-practices-azure-platform
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Shared Azure platform resource group against miniblue.
YAML

cat > index.ts <<'TS'
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

const environment = pulumi.getStack();
const location = "eastus";
const componentMinimumVersion = "1.1.0";

const group = new azure.core.ResourceGroup("postgres-platform-rg", {
  name: `bp-${environment}-postgres-rg`,
  location,
  tags: {
    owner: "platform-team",
    environment,
    managedBy: "pulumi",
    sharedInfrastructure: "postgres-resource-group",
    componentMinimumVersion,
  },
}, { provider: miniblue });

export const environmentName = environment;
export const resourceGroupName = group.name;
export const locationName = group.location;
export const minimumComponentVersion = componentMinimumVersion;
export const platformContract = pulumi.interpolate`Platform ${environment} exposes resource group ${group.name}`;
TS

npm install --no-audit --no-fund >/dev/null

cd /root/workspace/best-practices-azure/workload

cat > package.json <<'JSON'
{
  "name": "best-practices-azure-workload",
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
name: best-practices-azure-workload
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Workload PostgreSQL Flexible Servers using secure components and local policies.
config:
  componentVersion: "1.1.0"
  platformStack: "dev"
YAML

cat > src/provider.ts <<'TS'
import * as azure from "@pulumi/azure";

export const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});
TS

cat > src/secure-postgres.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

export type ServerSize = "dev" | "standard";
export type EnvironmentName = "dev" | "prod";

const SIZE_CONFIGS = {
  dev: { skuName: "B_Standard_B1ms", storageMb: 32768 },
  standard: { skuName: "GP_Standard_D2s_v3", storageMb: 65536 },
} as const;

export interface SecurePostgresServerArgs {
  service: string;
  environment: EnvironmentName;
  size: ServerSize;
  password: pulumi.Input<string>;
  resourceGroupName: pulumi.Input<string>;
  location: pulumi.Input<string>;
  componentVersion: string;
}

export class SecurePostgresServer extends pulumi.ComponentResource {
  public readonly fqdn: pulumi.Output<string>;
  public readonly serverName: pulumi.Output<string>;

  constructor(name: string, args: SecurePostgresServerArgs, opts?: pulumi.ComponentResourceOptions) {
    super("tutorial:best-practices:SecurePostgresServer", name, {}, opts);

    if (args.environment === "dev" && args.size !== "dev") {
      throw new Error("dev environment only allows the dev PostgreSQL server size");
    }

    const selected = SIZE_CONFIGS[args.size];
    const serverName = `${args.service}-${args.environment}`
      .toLowerCase()
      .replace(/[^a-z0-9-]/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 60);

    const server = new azure.postgresql.FlexibleServer(`${name}-server`, {
      name: serverName,
      resourceGroupName: args.resourceGroupName,
      location: args.location,
      version: "15",
      administratorLogin: "tutorial",
      administratorPassword: args.password,
      authentication: {
        activeDirectoryAuthEnabled: false,
        passwordAuthEnabled: true,
      },
      skuName: selected.skuName,
      storageMb: selected.storageMb,
      backupRetentionDays: 7,
      autoGrowEnabled: false,
      geoRedundantBackupEnabled: false,
      publicNetworkAccessEnabled: false,
      tags: {
        service: args.service,
        environment: args.environment,
        size: args.size,
        managedBy: "pulumi",
        componentName: "SecurePostgresServer",
        componentVersion: args.componentVersion,
        securityProfile: "baseline-postgres",
        costControlled: "true",
      },
    }, { parent: this });

    this.fqdn = server.fqdn;
    this.serverName = server.name;

    this.registerOutputs({
      fqdn: server.fqdn,
      serverName: server.name,
    });
  }
}
TS

cat > variants/good.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { miniblue } from "./src/provider";
import { EnvironmentName, SecurePostgresServer, ServerSize } from "./src/secure-postgres";

const config = new pulumi.Config();
const service = config.require("service");
const environment = config.require("environment") as EnvironmentName;
const size = config.require("size") as ServerSize;
const password = config.requireSecret("dbPassword");
const platformStack = config.get("platformStack") ?? environment;
const componentVersion = config.get("componentVersion") ?? "1.1.0";

const platform = new pulumi.StackReference(`organization/best-practices-azure-platform/${platformStack}`);

const database = new SecurePostgresServer(service, {
  service,
  environment,
  size,
  password,
  resourceGroupName: platform.requireOutput("resourceGroupName").apply(String),
  location: platform.requireOutput("locationName").apply(String),
  componentVersion,
}, { providers: [miniblue] });

export const serviceName = service;
export const environmentName = environment;
export const selectedSize = size;
export const serverName = database.serverName;
export const serverFqdn = database.fqdn;
export const platformContract = platform.requireOutput("platformContract");
TS

cat > variants/too-expensive.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { miniblue } from "./src/provider";
import { EnvironmentName, SecurePostgresServer } from "./src/secure-postgres";

const config = new pulumi.Config();
const service = config.require("service");
const environment = config.require("environment") as EnvironmentName;
const password = config.requireSecret("dbPassword");
const platformStack = config.get("platformStack") ?? environment;

const platform = new pulumi.StackReference(`organization/best-practices-azure-platform/${platformStack}`);

const database = new SecurePostgresServer(service, {
  service,
  environment,
  size: "standard",
  password,
  resourceGroupName: platform.requireOutput("resourceGroupName").apply(String),
  location: platform.requireOutput("locationName").apply(String),
  componentVersion: "1.1.0",
}, { providers: [miniblue] });

export const serverFqdn = database.fqdn;
TS

cat > variants/insecure-direct.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";
import { miniblue } from "./src/provider";

const config = new pulumi.Config();
const service = config.require("service");
const environment = config.require("environment");
const platformStack = config.get("platformStack") ?? environment;

const platform = new pulumi.StackReference(`organization/best-practices-azure-platform/${platformStack}`);

const direct = new azure.postgresql.FlexibleServer("direct-server", {
  name: `${service}-${environment}-direct`,
  resourceGroupName: platform.requireOutput("resourceGroupName").apply(String),
  location: platform.requireOutput("locationName").apply(String),
  version: "15",
  administratorLogin: "tutorial",
  administratorPassword: "Plaintext-Password1",
  authentication: {
    activeDirectoryAuthEnabled: false,
    passwordAuthEnabled: true,
  },
  skuName: "GP_Standard_D2s_v3",
  storageMb: 65536,
  backupRetentionDays: 7,
  publicNetworkAccessEnabled: true,
  tags: {
    service,
    environment,
    size: "standard",
  },
}, { provider: miniblue });

export const directFqdn = direct.fqdn;
TS

cp variants/good.ts index.ts
npm install --no-audit --no-fund >/dev/null

cd /root/workspace/best-practices-azure/policy-pack

cat > package.json <<'JSON'
{
  "name": "best-practices-azure-policy-pack",
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
description: Local Azure database best-practices policy pack.
author: Pulumi Tutorial
YAML

cat > index.ts <<'TS'
import { PolicyPack } from "@pulumi/policy";
import type { ResourceValidationPolicy } from "@pulumi/policy";

const databaseType = "azure:postgresql/flexibleServer:FlexibleServer";
const minimumComponentVersion = "1.1.0";

function tagsOf(props: Record<string, unknown>): Record<string, string> {
  return (props.tags || {}) as Record<string, string>;
}

function versionIsOlder(current: string, minimum: string): boolean {
  const currentParts = current.split(".").map(part => Number.parseInt(part, 10));
  const minimumParts = minimum.split(".").map(part => Number.parseInt(part, 10));
  for (let index = 0; index < Math.max(currentParts.length, minimumParts.length); index++) {
    const currentPart = currentParts[index] || 0;
    const minimumPart = minimumParts[index] || 0;
    if (currentPart < minimumPart) return true;
    if (currentPart > minimumPart) return false;
  }
  return false;
}

const requireSecureDatabaseDefaults: ResourceValidationPolicy = {
  name: "azure-postgresql-secure-defaults",
  description: "PostgreSQL Flexible Servers must use the secure component defaults.",
  enforcementLevel: "mandatory",
  validateResource: (args, reportViolation) => {
    if (args.type !== databaseType) return;
    const props = args.props as Record<string, unknown>;
    const tags = tagsOf(props);

    if (tags.componentName !== "SecurePostgresServer") {
      reportViolation("PostgreSQL servers must carry the SecurePostgresServer componentName tag.");
    }
    if (!tags.componentVersion || versionIsOlder(tags.componentVersion, minimumComponentVersion)) {
      reportViolation(`SecurePostgresServer version must be at least ${minimumComponentVersion}.`);
    }
    if (props.publicNetworkAccessEnabled !== false) {
      reportViolation("PostgreSQL servers must disable public network access in this tutorial.");
    }
    if (Number(props.backupRetentionDays || 0) < 7) {
      reportViolation("PostgreSQL servers must retain backups for at least seven days.");
    }
  },
};

const enforceDevCostProfile: ResourceValidationPolicy = {
  name: "azure-postgresql-dev-cost-profile",
  description: "dev servers must use the approved small profile.",
  enforcementLevel: "mandatory",
  validateResource: (args, reportViolation) => {
    if (args.type !== databaseType) return;
    const props = args.props as Record<string, unknown>;
    const tags = tagsOf(props);
    if (tags.environment !== "dev") return;

    if (props.skuName !== "B_Standard_B1ms") {
      reportViolation("dev PostgreSQL servers must use B_Standard_B1ms in this tutorial.");
    }
    if (Number(props.storageMb || 0) > 32768) {
      reportViolation("dev PostgreSQL servers must not allocate more than 32768 MiB.");
    }
  },
};

new PolicyPack("best-practices-azure", {
  policies: [requireSecureDatabaseDefaults, enforceDevCostProfile],
});
TS

npm install --no-audit --no-fund >/dev/null

pulumi login --local >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Best practices Azure lab is ready in /root/workspace/best-practices-azure"