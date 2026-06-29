#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-component-packaging-azure"
export SCENARIO_TITLE="Component 包分发与基于 Git 的版本化引用：Azure / miniblue 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

log_step() {
  echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] $* ====="
}

rm -f /tmp/.setup-done
mkdir -p /root/workspace /root/repos

log_step "安装 Pulumi、Node.js 与共享工具"
bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi

log_step "安装辅助工具并启动 Docker"
apt-get install -y jq openssl >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

git config --global user.email "tutorial@example.com"
git config --global user.name "Pulumi Tutorial"
git config --global init.defaultBranch main

cd /root/workspace

log_step "生成本地 Git 仓库和消费者项目"

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-39cc27a
    container_name: pulumi-component-packaging-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
      MINIBLUE_DISABLE_SHAREDKEY_AUTH: "1"
      MINIBLUE_STORAGE_ENDPOINT: http://localhost:4566
YAML

SOURCE_WORK=/root/repos/azure-secure-storage-source-work
SOURCE_BARE=/root/repos/azure-secure-storage-source.git
NATIVE_WORK=/root/repos/azure-secure-storage-native-work
NATIVE_BARE=/root/repos/azure-secure-storage-native.git
EXEC_WORK=/root/repos/azure-secure-exec-provider

rm -rf "$SOURCE_WORK" "$SOURCE_BARE" "$NATIVE_WORK" "$NATIVE_BARE" "$EXEC_WORK"
mkdir -p "$SOURCE_WORK" "$NATIVE_WORK/dist" "$EXEC_WORK"

cat > "$SOURCE_WORK/.gitignore" <<'EOF'
node_modules/
package-lock.json
EOF

cat > "$SOURCE_WORK/PulumiPlugin.yaml" <<'YAML'
runtime: nodejs
YAML

cat > "$SOURCE_WORK/package.json" <<'JSON'
{
  "name": "azure-secure-storage",
  "version": "0.1.0",
  "main": "index.ts",
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

cat > "$SOURCE_WORK/tsconfig.json" <<'JSON'
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

cat > "$SOURCE_WORK/index.ts" <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as core from "@pulumi/azure/core";
import * as storage from "@pulumi/azure/storage";

export interface SecureStorageArgs {
  team: pulumi.Input<string>;
  location?: pulumi.Input<string>;
}

export class SecureStorage extends pulumi.ComponentResource {
  public readonly accountName: pulumi.Output<string>;
  public readonly logsAccountName: pulumi.Output<string>;

  constructor(name: string, args: SecureStorageArgs, opts?: pulumi.ComponentResourceOptions) {
    super("azure-secure-storage:index:SecureStorage", name, args, opts);

    const location = args.location ?? "eastus";
    const tags = {
      team: args.team,
      managedBy: "platform",
    };
    const slug = name.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 12) || "storage";

    const rg = new core.ResourceGroup(`${name}-rg`, { location, tags }, { parent: this });
    const logs = new storage.Account(`${name}-logs`, {
      name: `${slug}logs`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, { parent: this });
    const account = new storage.Account(`${name}-data`, {
      name: `${slug}data`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, { parent: this });

    this.accountName = account.name;
    this.logsAccountName = logs.name;

    this.registerOutputs({
      accountName: account.name,
      logsAccountName: logs.name,
    });
  }
}
TS

cat > "$SOURCE_WORK/README.md" <<'MD'
# azure-secure-storage

Source-based Pulumi plugin package that exposes a SecureStorage component.
MD

git -C "$SOURCE_WORK" init >/dev/null
git -C "$SOURCE_WORK" add .
git -C "$SOURCE_WORK" commit -m "release source package v0.1.0" >/dev/null
git -C "$SOURCE_WORK" tag v0.1.0
git clone --bare "$SOURCE_WORK" "$SOURCE_BARE" >/dev/null 2>&1

cat > "$NATIVE_WORK/.gitignore" <<'EOF'
node_modules/
package-lock.json
EOF

cat > "$NATIVE_WORK/package.json" <<'JSON'
{
  "name": "azure-secure-storage-native",
  "version": "0.1.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "dependencies": {
    "@pulumi/azure": "^6.0.0",
    "@pulumi/pulumi": "^3.0.0"
  }
}
JSON

cat > "$NATIVE_WORK/dist/index.js" <<'JS'
const pulumi = require("@pulumi/pulumi");
const core = require("@pulumi/azure/core");
const storage = require("@pulumi/azure/storage");

class SecureStorage extends pulumi.ComponentResource {
  constructor(name, args, opts) {
    super("azure-secure-storage-native:index:SecureStorage", name, args, opts);

    const location = args.location || "eastus";
    const tags = {
      team: args.team,
      managedBy: "platform",
    };
    const slug = name.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 12) || "storage";

    const rg = new core.ResourceGroup(`${name}-rg`, { location, tags }, { parent: this });
    const logs = new storage.Account(`${name}-logs`, {
      name: `${slug}logs`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, { parent: this });
    const account = new storage.Account(`${name}-data`, {
      name: `${slug}data`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, { parent: this });

    this.accountName = account.name;
    this.logsAccountName = logs.name;

    this.registerOutputs({
      accountName: account.name,
      logsAccountName: logs.name,
    });
  }
}

module.exports = { SecureStorage };
JS

cat > "$NATIVE_WORK/dist/index.d.ts" <<'TS'
import * as pulumi from "@pulumi/pulumi";

export interface SecureStorageArgs {
  team: pulumi.Input<string>;
  location?: pulumi.Input<string>;
}

export declare class SecureStorage extends pulumi.ComponentResource {
  readonly accountName: pulumi.Output<string>;
  readonly logsAccountName: pulumi.Output<string>;
  constructor(name: string, args: SecureStorageArgs, opts?: pulumi.ComponentResourceOptions);
}
TS

cat > "$NATIVE_WORK/README.md" <<'MD'
# azure-secure-storage-native

Native TypeScript package that exposes a SecureStorage component.
MD

git -C "$NATIVE_WORK" init >/dev/null
git -C "$NATIVE_WORK" add .
git -C "$NATIVE_WORK" commit -m "release native package v0.1.0" >/dev/null
git -C "$NATIVE_WORK" tag v0.1.0
git clone --bare "$NATIVE_WORK" "$NATIVE_BARE" >/dev/null 2>&1

cat > "$EXEC_WORK/go.mod" <<'EOF'
module local/azure-secure-exec

go 1.23

require github.com/pulumi/pulumi-go-provider v1.3.2
EOF

cat > "$EXEC_WORK/main.go" <<'GO'
package main

import (
  "context"
  "fmt"
  "os"

  p "github.com/pulumi/pulumi-go-provider"
  "github.com/pulumi/pulumi-go-provider/infer"
  "github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

const packageName = "azure-secure-exec"
const version = "0.1.0"

type ExecutableNameplateArgs struct {
  Team     pulumi.StringInput `pulumi:"team"`
  Location pulumi.StringInput `pulumi:"location"`
}

type ExecutableNameplate struct {
  pulumi.ResourceState
  Nameplate pulumi.StringOutput `pulumi:"nameplate"`
}

func NewExecutableNameplate(ctx *pulumi.Context, name string, args ExecutableNameplateArgs, opts ...pulumi.ResourceOption) (*ExecutableNameplate, error) {
  component := &ExecutableNameplate{}
  if err := ctx.RegisterComponentResource(p.GetTypeToken(ctx.Context()), name, component, opts...); err != nil {
    return nil, err
  }

  location := args.Location
  component.Nameplate = pulumi.Sprintf("%s-%s-%s", args.Team, name, location)
  return component, nil
}

func main() {
  provider, err := infer.NewProviderBuilder().
    WithDisplayName("Azure Secure Executable Components").
    WithDescription("A local executable-based component provider for the Pulumi tutorial.").
    WithLanguageMap(map[string]any{
      "nodejs": map[string]any{
        "packageName":          "azure-secure-exec",
        "respectSchemaVersion": true,
      },
      "go": map[string]any{
        "importBasePath":                 "local-package/sdk/go/azure-secure-exec",
        "generateResourceContainerTypes": true,
        "respectSchemaVersion":           true,
      },
      "python": map[string]any{
        "respectSchemaVersion": true,
        "pyproject": map[string]any{
          "enabled": true,
        },
      },
      "csharp": map[string]any{
        "respectSchemaVersion": true,
      },
    }).
    WithComponents(
      infer.ComponentF(NewExecutableNameplate),
    ).
    Build()
  if err != nil {
    fmt.Fprintln(os.Stderr, err)
    os.Exit(1)
  }

  if err := provider.Run(context.Background(), packageName, version); err != nil {
    fmt.Fprintln(os.Stderr, err)
    os.Exit(1)
  }
}
GO

mkdir -p "$EXEC_WORK/bin"

for project in native-consumer source-consumer exec-consumer; do
  mkdir -p "/root/workspace/$project"
  cat > "/root/workspace/$project/package.json" <<'JSON'
{
  "name": "azure-secure-storage-consumer",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@pulumi/azure": "^6.0.0",
    "@pulumi/pulumi": "^3.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
JSON
  cat > "/root/workspace/$project/tsconfig.json" <<'JSON'
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
  cat > "/root/workspace/$project/Pulumi.yaml" <<YAML
name: $project
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=1536"
description: Consume a Git-tagged SecureStorage component package against miniblue.
YAML
done

cat > /root/workspace/native-consumer/index.ts <<'TS'
import { Provider } from "@pulumi/azure/provider";
import { SecureStorage } from "azure-secure-storage-native";

const miniblue = new Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

const storage = new SecureStorage("native", { team: "platform", location: "eastus" }, { providers: [miniblue] });

export const accountName = storage.accountName;
export const logsAccountName = storage.logsAccountName;
TS

cat > /root/workspace/source-consumer/index.ts <<'TS'
import { Provider } from "@pulumi/azure/provider";
import { SecureStorage } from "@pulumi/azure-secure-storage";

const miniblue = new Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

const storage = new SecureStorage("source", { team: "platform", location: "eastus" }, { providers: [miniblue] });

export const accountName = storage.accountName;
export const logsAccountName = storage.logsAccountName;
TS

cat > /root/workspace/exec-consumer/index.ts <<'TS'
import { ExecutableNameplate } from "azure-secure-exec";

const nameplate = new ExecutableNameplate("exec-storage", {
  team: "platform",
  location: "eastus",
});

export const generatedNameplate = nameplate.nameplate;
TS

log_step "预安装 npm 依赖（尽力而为，有超时保护）"
timeout 90s npm install --prefix /root/workspace/native-consumer --no-audit --no-fund >/dev/null 2>&1 || true
timeout 90s npm install --prefix /root/workspace/source-consumer --no-audit --no-fund >/dev/null 2>&1 || true
timeout 60s npm install --prefix /root/workspace/exec-consumer --no-audit --no-fund >/dev/null 2>&1 || true
timeout 90s npm install --prefix "$SOURCE_WORK" --no-audit --no-fund >/dev/null 2>&1 || true

log_step "初始化本地 Pulumi stacks"
pulumi login --local >/dev/null 2>&1 || true
for project in native-consumer source-consumer exec-consumer; do
  (cd "/root/workspace/$project" && pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true)
done

log_step "启动 miniblue 并等待 metadata 端口"
timeout 300s docker pull ghcr.io/lonegunmanb/miniblue:sha-39cc27a >/dev/null 2>&1 || true
docker compose up -d >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" >/dev/null 2>&1 && break
  sleep 2
done

openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 > /usr/local/share/ca-certificates/miniblue.crt 2>/dev/null || true
update-ca-certificates >/dev/null 2>&1 || true

touch /tmp/.setup-done
log_step "初始化完成"
echo "Azure component packaging lab is ready in /root/workspace"