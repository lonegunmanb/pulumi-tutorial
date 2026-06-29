#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-component-packaging-aws"
export SCENARIO_TITLE="Component 包分发与基于 Git 的版本化引用：AWS / MiniStack 版"
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

log_step "启动 Docker 并检查 compose"
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
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-component-packaging-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

SOURCE_WORK=/root/repos/aws-secure-bucket-source-work
SOURCE_BARE=/root/repos/aws-secure-bucket-source.git
NATIVE_WORK=/root/repos/aws-secure-bucket-native-work
NATIVE_BARE=/root/repos/aws-secure-bucket-native.git
EXEC_WORK=/root/repos/aws-secure-exec-provider

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
  "name": "aws-secure-bucket",
  "version": "0.1.0",
  "main": "index.ts",
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
import * as s3 from "@pulumi/aws/s3";

export interface SecureBucketArgs {
  team: pulumi.Input<string>;
}

export class SecureBucket extends pulumi.ComponentResource {
  public readonly bucketName: pulumi.Output<string>;
  public readonly logsBucketName: pulumi.Output<string>;

  constructor(name: string, args: SecureBucketArgs, opts?: pulumi.ComponentResourceOptions) {
    super("aws-secure-bucket:index:SecureBucket", name, args, opts);

    const tags = {
      team: args.team,
      managedBy: "platform",
    };

    const logs = new s3.Bucket(`${name}-logs`, { tags }, { parent: this });
    const bucket = new s3.Bucket(`${name}-bucket`, { tags }, { parent: this });

    this.bucketName = bucket.bucket;
    this.logsBucketName = logs.bucket;

    this.registerOutputs({
      bucketName: bucket.bucket,
      logsBucketName: logs.bucket,
    });
  }
}
TS

cat > "$SOURCE_WORK/README.md" <<'MD'
# aws-secure-bucket

Source-based Pulumi plugin package that exposes a SecureBucket component.
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
  "name": "aws-secure-bucket-native",
  "version": "0.1.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "dependencies": {
    "@pulumi/aws": "^7.0.0",
    "@pulumi/pulumi": "^3.0.0"
  }
}
JSON

cat > "$NATIVE_WORK/dist/index.js" <<'JS'
const pulumi = require("@pulumi/pulumi");
const s3 = require("@pulumi/aws/s3");

class SecureBucket extends pulumi.ComponentResource {
  constructor(name, args, opts) {
    super("aws-secure-bucket-native:index:SecureBucket", name, args, opts);

    const tags = {
      team: args.team,
      managedBy: "platform",
    };

    const logs = new s3.Bucket(`${name}-logs`, { tags }, { parent: this });
    const bucket = new s3.Bucket(`${name}-bucket`, { tags }, { parent: this });

    this.bucketName = bucket.bucket;
    this.logsBucketName = logs.bucket;

    this.registerOutputs({
      bucketName: bucket.bucket,
      logsBucketName: logs.bucket,
    });
  }
}

module.exports = { SecureBucket };
JS

cat > "$NATIVE_WORK/dist/index.d.ts" <<'TS'
import * as pulumi from "@pulumi/pulumi";

export interface SecureBucketArgs {
  team: pulumi.Input<string>;
}

export declare class SecureBucket extends pulumi.ComponentResource {
  readonly bucketName: pulumi.Output<string>;
  readonly logsBucketName: pulumi.Output<string>;
  constructor(name: string, args: SecureBucketArgs, opts?: pulumi.ComponentResourceOptions);
}
TS

cat > "$NATIVE_WORK/README.md" <<'MD'
# aws-secure-bucket-native

Native TypeScript package that exposes a SecureBucket component.
MD

git -C "$NATIVE_WORK" init >/dev/null
git -C "$NATIVE_WORK" add .
git -C "$NATIVE_WORK" commit -m "release native package v0.1.0" >/dev/null
git -C "$NATIVE_WORK" tag v0.1.0
git clone --bare "$NATIVE_WORK" "$NATIVE_BARE" >/dev/null 2>&1

cat > "$EXEC_WORK/go.mod" <<'EOF'
module local/aws-secure-exec

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

const packageName = "aws-secure-exec"
const version = "0.1.0"

type ExecutableLabelArgs struct {
  Team pulumi.StringInput `pulumi:"team"`
}

type ExecutableLabel struct {
  pulumi.ResourceState
  Label pulumi.StringOutput `pulumi:"label"`
}

func NewExecutableLabel(ctx *pulumi.Context, name string, args ExecutableLabelArgs, opts ...pulumi.ResourceOption) (*ExecutableLabel, error) {
  component := &ExecutableLabel{}
  if err := ctx.RegisterComponentResource(p.GetTypeToken(ctx.Context()), name, component, opts...); err != nil {
    return nil, err
  }

  component.Label = pulumi.Sprintf("%s-%s", args.Team, name)
  return component, nil
}

func main() {
  provider, err := infer.NewProviderBuilder().
    WithDisplayName("AWS Secure Executable Components").
    WithDescription("A local executable-based component provider for the Pulumi tutorial.").
    WithLanguageMap(map[string]any{
      "nodejs": map[string]any{
        "packageName":          "aws-secure-exec",
        "respectSchemaVersion": true,
      },
      "go": map[string]any{
        "importBasePath":                 "local-package/sdk/go/aws-secure-exec",
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
      infer.ComponentF(NewExecutableLabel),
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
  "name": "aws-secure-bucket-consumer",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@pulumi/aws": "^7.0.0",
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
description: Consume a Git-tagged SecureBucket component package against MiniStack.
YAML
done

cat > /root/workspace/native-consumer/index.ts <<'TS'
import { Provider } from "@pulumi/aws/provider";
import { SecureBucket } from "aws-secure-bucket-native";

const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566" }],
});

const media = new SecureBucket("native-media", { team: "platform" }, { providers: [localAws] });

export const bucketName = media.bucketName;
export const logsBucketName = media.logsBucketName;
TS

cat > /root/workspace/source-consumer/index.ts <<'TS'
import { Provider } from "@pulumi/aws/provider";
import { SecureBucket } from "aws-secure-bucket";

const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566" }],
});

const media = new SecureBucket("source-media", { team: "platform" }, { providers: [localAws] });

export const bucketName = media.bucketName;
export const logsBucketName = media.logsBucketName;
TS

cat > /root/workspace/exec-consumer/index.ts <<'TS'
import { ExecutableLabel } from "aws-secure-exec";

const label = new ExecutableLabel("exec-media", { team: "platform" });

export const generatedLabel = label.label;
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

log_step "启动 MiniStack 并等待健康检查"
timeout 300s docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true
docker compose up -d >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1 && break
  sleep 2
done

touch /tmp/.setup-done
log_step "初始化完成"
echo "AWS component packaging lab is ready in /root/workspace"