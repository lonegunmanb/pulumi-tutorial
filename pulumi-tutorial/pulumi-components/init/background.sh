#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-components"
export SCENARIO_TITLE="ComponentResource 组件化：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

rm -f /tmp/.setup-done
mkdir -p /root/workspace

# 安装 Pulumi、Node.js 与共享工具（尽力而为，单步失败不影响后续）。
bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi

# Killercoda 已预装 Docker，这里只确保守护进程在运行。
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
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-components-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-components-aws-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
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

cat > Pulumi.yaml <<'YAML'
name: pulumi-components
runtime: nodejs
description: Encapsulate AWS S3 buckets into a SecureBucket ComponentResource against MiniStack.
YAML

# ---------- 共享的 provider 片段（把 AWS 调用指向本地 MiniStack） ----------
read -r -d '' PROVIDER_TS <<'TS'
import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

// 用显式配置的 provider 把所有 AWS 调用指向本地 MiniStack，而非真实 AWS。
const localAws = new aws.Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566" }],
});
TS

# ---------- 共享的组件定义（v1：子资源名 ${name}-logs / ${name}-bucket） ----------
read -r -d '' COMPONENT_TS <<'TS'
// SecureBucket：把"主桶 + 访问日志桶 + 强制标签"封装成一个组件。
export interface SecureBucketArgs {
  team: pulumi.Input<string>;
}

export class SecureBucket extends pulumi.ComponentResource {
  public readonly bucketName: pulumi.Output<string>;
  public readonly logsBucketName: pulumi.Output<string>;

  constructor(name: string, args: SecureBucketArgs, opts?: pulumi.ComponentResourceOptions) {
    // 类型名格式固定：<package>:index:<类名>，部署后不要再改。
    super("acme:index:SecureBucket", name, args, opts);

    // 组件强制注入的标签（团队的合规默认值）。
    const tags = { team: args.team, managedBy: "platform" };

    // 子资源都设 parent: this，并用 ${name} 拼前缀，保证多实例不撞名。
    const logs = new aws.s3.Bucket(`${name}-logs`, { tags }, { parent: this });
    const bucket = new aws.s3.Bucket(`${name}-bucket`, { tags }, { parent: this });

    this.bucketName = bucket.bucket;
    this.logsBucketName = logs.bucket;

    // 收尾：注册输出，标记组件构造完成。
    this.registerOutputs({
      bucketName: bucket.bucket,
      logsBucketName: logs.bucket,
    });
  }
}
TS

# ---------- flat / step1：平铺资源，没有组件、没有层级 ----------
cat > variants/flat.ts <<TS
${PROVIDER_TS}

// 平铺写法：两个桶直接声明，彼此没有共同的父，state 是扁平的。
const tags = { team: "platform", managedBy: "platform" };

const mediaLogs = new aws.s3.Bucket("media-logs", { tags }, { provider: localAws });
const mediaBucket = new aws.s3.Bucket("media-bucket", { tags }, { provider: localAws });

export const mediaBucketName = mediaBucket.bucket;
export const mediaLogsName = mediaLogs.bucket;
TS

# ---------- component / step2：封装成单个组件实例 ----------
cat > variants/component.ts <<TS
${PROVIDER_TS}

${COMPONENT_TS}

// 实例化组件和实例化普通资源一样：name + args + options。
// provider 用 providers（复数）传给组件，会下传给每个 parent: this 的子资源。
const media = new SecureBucket("media", { team: "platform" }, { providers: [localAws] });

export const mediaBucketName = media.bucketName;
export const mediaLogsName = media.logsBucketName;
TS

# ---------- reuse / step3：同一个组件实例化两次 ----------
cat > variants/reuse.ts <<TS
${PROVIDER_TS}

${COMPONENT_TS}

// 复用：实例化两次，子资源名会分别带上各自的实例名前缀。
const media = new SecureBucket("media", { team: "platform" }, { providers: [localAws] });
const backups = new SecureBucket("backups", { team: "platform" }, { providers: [localAws] });

export const mediaBucketName = media.bucketName;
export const mediaLogsName = media.logsBucketName;
export const backupsBucketName = backups.bucketName;
export const backupsLogsName = backups.logsBucketName;
TS

# ---------- evolve-broken / step4-pre：在组件内给子资源改名，但没加 alias ----------
read -r -d '' COMPONENT_RENAMED_TS <<'TS'
export interface SecureBucketArgs {
  team: pulumi.Input<string>;
}

export class SecureBucket extends pulumi.ComponentResource {
  public readonly bucketName: pulumi.Output<string>;
  public readonly logsBucketName: pulumi.Output<string>;

  constructor(name: string, args: SecureBucketArgs, opts?: pulumi.ComponentResourceOptions) {
    super("acme:index:SecureBucket", name, args, opts);

    const tags = { team: args.team, managedBy: "platform" };

    // 把日志桶的 logical name 从 ${name}-logs 改成 ${name}-access-logs（没有 alias）。
    const logs = new aws.s3.Bucket(`${name}-access-logs`, { tags }, { parent: this });
    const bucket = new aws.s3.Bucket(`${name}-bucket`, { tags }, { parent: this });

    this.bucketName = bucket.bucket;
    this.logsBucketName = logs.bucket;

    this.registerOutputs({
      bucketName: bucket.bucket,
      logsBucketName: logs.bucket,
    });
  }
}
TS

cat > variants/evolve-broken.ts <<TS
${PROVIDER_TS}

${COMPONENT_RENAMED_TS}

const media = new SecureBucket("media", { team: "platform" }, { providers: [localAws] });
const backups = new SecureBucket("backups", { team: "platform" }, { providers: [localAws] });

export const mediaBucketName = media.bucketName;
export const mediaLogsName = media.logsBucketName;
export const backupsBucketName = backups.bucketName;
export const backupsLogsName = backups.logsBucketName;
TS

# ---------- evolve-fixed / step4：同样改名，但用 aliases 认领旧子资源（零重建） ----------
read -r -d '' COMPONENT_ALIASED_TS <<'TS'
export interface SecureBucketArgs {
  team: pulumi.Input<string>;
}

export class SecureBucket extends pulumi.ComponentResource {
  public readonly bucketName: pulumi.Output<string>;
  public readonly logsBucketName: pulumi.Output<string>;

  constructor(name: string, args: SecureBucketArgs, opts?: pulumi.ComponentResourceOptions) {
    super("acme:index:SecureBucket", name, args, opts);

    const tags = { team: args.team, managedBy: "platform" };

    // 改名 + aliases：告诉 Pulumi "${name}-access-logs 就是以前的 ${name}-logs"。
    const logs = new aws.s3.Bucket(`${name}-access-logs`, { tags }, {
      parent: this,
      aliases: [{ name: `${name}-logs` }],
    });
    const bucket = new aws.s3.Bucket(`${name}-bucket`, { tags }, { parent: this });

    this.bucketName = bucket.bucket;
    this.logsBucketName = logs.bucket;

    this.registerOutputs({
      bucketName: bucket.bucket,
      logsBucketName: logs.bucket,
    });
  }
}
TS

cat > variants/evolve-fixed.ts <<TS
${PROVIDER_TS}

${COMPONENT_ALIASED_TS}

const media = new SecureBucket("media", { team: "platform" }, { providers: [localAws] });
const backups = new SecureBucket("backups", { team: "platform" }, { providers: [localAws] });

export const mediaBucketName = media.bucketName;
export const mediaLogsName = media.logsBucketName;
export const backupsBucketName = backups.bucketName;
export const backupsLogsName = backups.logsBucketName;
TS

# 初始程序使用 flat 变体。
cp variants/flat.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true

# 启动 MiniStack 并等待健康检查通过，学员到 step1 时即可直接部署。
docker compose up -d >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1 && break
  sleep 2
done

touch /tmp/.setup-done
echo "AWS / MiniStack components lab is ready in /root/workspace"
