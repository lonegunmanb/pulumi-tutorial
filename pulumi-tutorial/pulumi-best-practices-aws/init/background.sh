#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-best-practices-aws"
export SCENARIO_TITLE="最佳实践：AWS / MiniStack RDS 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done

bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

apt-get install -y jq >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

cat > /root/.pulumi-best-practices-aws-env.sh <<'SH'
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
SH

if ! grep -q '.pulumi-best-practices-aws-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-best-practices-aws-env.sh' >> /root/.bashrc
fi

mkdir -p /root/workspace/best-practices-aws/platform \
  /root/workspace/best-practices-aws/workload/src \
  /root/workspace/best-practices-aws/workload/variants \
  /root/workspace/best-practices-aws/policy-pack

cd /root/workspace/best-practices-aws

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-best-practices-ministack
    ports:
      - "4566:4566"
      - "15432-15450:15432-15450"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
      RDS_BASE_PORT: "15432"
YAML

docker compose up -d

for attempt in $(seq 1 90); do
  if curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" = "90" ]; then
    docker compose logs
    exit 1
  fi
  sleep 2
done

cd /root/workspace/best-practices-aws/platform

cat > package.json <<'JSON'
{
  "name": "best-practices-aws-platform",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@pulumi/aws": "^7.0.0",
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
name: best-practices-aws-platform
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Shared PostgreSQL platform baseline against MiniStack RDS.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as rds from "@pulumi/aws/rds";
import { Provider } from "@pulumi/aws/provider";

const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  endpoints: [{ rds: "http://localhost:4566", sts: "http://localhost:4566" }],
});

const environment = pulumi.getStack();
const componentMinimumVersion = "1.1.0";

const baseline = new rds.ParameterGroup("postgres-baseline", {
  family: "postgres15",
  description: `Shared PostgreSQL baseline for ${environment}`,
  parameters: [
    { name: "log_statement", value: "ddl" },
    { name: "log_min_duration_statement", value: "1000" },
  ],
  tags: {
    owner: "platform-team",
    environment,
    managedBy: "pulumi",
    sharedInfrastructure: "postgres-baseline",
    componentMinimumVersion,
  },
}, { provider: localAws });

export const environmentName = environment;
export const parameterGroupName = baseline.name;
export const minimumComponentVersion = componentMinimumVersion;
export const platformContract = pulumi.interpolate`Platform ${environment} exposes parameter group ${baseline.name}`;
TS

npm install --no-audit --no-fund >/dev/null

cd /root/workspace/best-practices-aws/workload

cat > package.json <<'JSON'
{
  "name": "best-practices-aws-workload",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@pulumi/aws": "^7.0.0",
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
name: best-practices-aws-workload
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Workload PostgreSQL databases using secure components and local policies.
config:
  componentVersion: "1.1.0"
  platformStack: "dev"
YAML

cat > src/provider.ts <<'TS'
import { Provider } from "@pulumi/aws/provider";

export const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  endpoints: [{ rds: "http://localhost:4566", sts: "http://localhost:4566" }],
});
TS

cat > src/secure-postgres.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as rds from "@pulumi/aws/rds";

export type DatabaseSize = "dev" | "standard";
export type EnvironmentName = "dev" | "prod";

const SIZE_CONFIGS = {
  dev: { instanceClass: "db.t3.micro", storage: 20 },
  standard: { instanceClass: "db.t3.small", storage: 40 },
} as const;

export interface SecurePostgresDatabaseArgs {
  service: string;
  environment: EnvironmentName;
  size: DatabaseSize;
  password: pulumi.Input<string>;
  platformParameterGroupName: pulumi.Input<string>;
  componentVersion: string;
}

export class SecurePostgresDatabase extends pulumi.ComponentResource {
  public readonly endpoint: pulumi.Output<string>;
  public readonly identifier: pulumi.Output<string>;

  constructor(name: string, args: SecurePostgresDatabaseArgs, opts?: pulumi.ComponentResourceOptions) {
    super("tutorial:best-practices:SecurePostgresDatabase", name, {}, opts);

    if (args.environment === "dev" && args.size !== "dev") {
      throw new Error("dev environment only allows the dev database size");
    }

    const selected = SIZE_CONFIGS[args.size];
    const identifier = `${args.service}-${args.environment}`
      .toLowerCase()
      .replace(/[^a-z0-9-]/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 60);
    const databaseName = args.service.replace(/[^A-Za-z0-9_]/g, "_").slice(0, 50) || "appdb";

    const db = new rds.Instance(`${name}-db`, {
      identifier,
      dbName: databaseName,
      engine: "postgres",
      engineVersion: "15",
      instanceClass: selected.instanceClass,
      allocatedStorage: selected.storage,
      username: "tutorial",
      password: args.password,
      parameterGroupName: args.platformParameterGroupName,
      skipFinalSnapshot: true,
      applyImmediately: true,
      storageEncrypted: true,
      publiclyAccessible: false,
      backupRetentionPeriod: 1,
      autoMinorVersionUpgrade: true,
      deletionProtection: false,
      tags: {
        service: args.service,
        environment: args.environment,
        size: args.size,
        managedBy: "pulumi",
        componentName: "SecurePostgresDatabase",
        componentVersion: args.componentVersion,
        securityProfile: "baseline-postgres",
        costControlled: "true",
      },
    }, { parent: this, ignoreChanges: ["maxAllocatedStorage"] });

    this.endpoint = db.endpoint;
    this.identifier = db.identifier;

    this.registerOutputs({
      endpoint: db.endpoint,
      identifier: db.identifier,
    });
  }
}
TS

cat > variants/good.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { localAws } from "./src/provider";
import { DatabaseSize, EnvironmentName, SecurePostgresDatabase } from "./src/secure-postgres";

const config = new pulumi.Config();
const service = config.require("service");
const environment = config.require("environment") as EnvironmentName;
const size = config.require("size") as DatabaseSize;
const password = config.requireSecret("dbPassword");
const platformStack = config.get("platformStack") ?? environment;
const componentVersion = config.get("componentVersion") ?? "1.1.0";

const platform = new pulumi.StackReference(`organization/best-practices-aws-platform/${platformStack}`);
const parameterGroupName = platform.requireOutput("parameterGroupName").apply(String);

const database = new SecurePostgresDatabase(service, {
  service,
  environment,
  size,
  password,
  platformParameterGroupName: parameterGroupName,
  componentVersion,
}, { providers: [localAws] });

export const serviceName = service;
export const environmentName = environment;
export const selectedSize = size;
export const dbIdentifier = database.identifier;
export const dbEndpoint = database.endpoint;
export const platformContract = platform.requireOutput("platformContract");
TS

cat > variants/too-expensive.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { localAws } from "./src/provider";
import { EnvironmentName, SecurePostgresDatabase } from "./src/secure-postgres";

const config = new pulumi.Config();
const service = config.require("service");
const environment = config.require("environment") as EnvironmentName;
const password = config.requireSecret("dbPassword");
const platformStack = config.get("platformStack") ?? environment;

const platform = new pulumi.StackReference(`organization/best-practices-aws-platform/${platformStack}`);

const database = new SecurePostgresDatabase(service, {
  service,
  environment,
  size: "standard",
  password,
  platformParameterGroupName: platform.requireOutput("parameterGroupName").apply(String),
  componentVersion: "1.1.0",
}, { providers: [localAws] });

export const dbEndpoint = database.endpoint;
TS

cat > variants/insecure-direct.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as rds from "@pulumi/aws/rds";
import { localAws } from "./src/provider";

const config = new pulumi.Config();
const service = config.require("service");
const environment = config.require("environment");

const direct = new rds.Instance("direct-db", {
  identifier: `${service}-${environment}-direct`,
  dbName: service.replace(/[^A-Za-z0-9_]/g, "_") || "appdb",
  engine: "postgres",
  engineVersion: "15",
  instanceClass: "db.t3.small",
  allocatedStorage: 40,
  username: "tutorial",
  password: "Plaintext-Password1",
  skipFinalSnapshot: true,
  storageEncrypted: false,
  publiclyAccessible: true,
  backupRetentionPeriod: 0,
  tags: {
    service,
    environment,
    size: "standard",
  },
}, { provider: localAws, ignoreChanges: ["maxAllocatedStorage"] });

export const directEndpoint = direct.endpoint;
TS

cp variants/good.ts index.ts
npm install --no-audit --no-fund >/dev/null

cd /root/workspace/best-practices-aws/policy-pack

cat > package.json <<'JSON'
{
  "name": "best-practices-aws-policy-pack",
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
description: Local AWS database best-practices policy pack.
author: Pulumi Tutorial
YAML

cat > index.ts <<'TS'
import { PolicyPack } from "@pulumi/policy";
import type { ResourceValidationPolicy } from "@pulumi/policy";

const databaseType = "aws:rds/instance:Instance";
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
  name: "aws-rds-secure-defaults",
  description: "RDS PostgreSQL instances must use the secure database component defaults.",
  enforcementLevel: "mandatory",
  validateResource: (args, reportViolation) => {
    if (args.type !== databaseType) return;
    const props = args.props as Record<string, unknown>;
    const tags = tagsOf(props);

    if (tags.componentName !== "SecurePostgresDatabase") {
      reportViolation("RDS instances must carry the SecurePostgresDatabase componentName tag.");
    }
    if (!tags.componentVersion || versionIsOlder(tags.componentVersion, minimumComponentVersion)) {
      reportViolation(`SecurePostgresDatabase version must be at least ${minimumComponentVersion}.`);
    }
    if (props.storageEncrypted !== true) {
      reportViolation("RDS instances must enable storage encryption.");
    }
    if (props.publiclyAccessible === true) {
      reportViolation("RDS instances must not be publicly accessible.");
    }
    if (Number(props.backupRetentionPeriod || 0) < 1) {
      reportViolation("RDS instances must retain automated backups for at least one day.");
    }
  },
};

const enforceDevCostProfile: ResourceValidationPolicy = {
  name: "aws-rds-dev-cost-profile",
  description: "dev databases must use the approved small profile.",
  enforcementLevel: "mandatory",
  validateResource: (args, reportViolation) => {
    if (args.type !== databaseType) return;
    const props = args.props as Record<string, unknown>;
    const tags = tagsOf(props);
    if (tags.environment !== "dev") return;

    if (props.instanceClass !== "db.t3.micro") {
      reportViolation("dev RDS instances must use db.t3.micro in this tutorial.");
    }
    if (Number(props.allocatedStorage || 0) > 20) {
      reportViolation("dev RDS instances must not allocate more than 20 GiB.");
    }
  },
};

new PolicyPack("best-practices-aws", {
  policies: [requireSecureDatabaseDefaults, enforceDevCostProfile],
});
TS

npm install --no-audit --no-fund >/dev/null

pulumi login --local >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Best practices AWS lab is ready in /root/workspace/best-practices-aws"