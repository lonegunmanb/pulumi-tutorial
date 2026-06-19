#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-resources-options"
export SCENARIO_TITLE="资源与精细控制：AWS / MiniStack 版"
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
  localstack:
    image: localstack/localstack:3
    container_name: pulumi-resources-localstack
    ports:
      - "4566:4566"
    environment:
      DEBUG: "0"
      SERVICES: "s3,ec2,sts"
      AWS_DEFAULT_REGION: us-east-1
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-resources-options-aws-lab",
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
name: pulumi-resources-options
runtime: nodejs
description: Explore resource names, identity and options with the AWS provider against MiniStack.
YAML

# ---------- 共享的 provider 片段（每个变体都会复用） ----------
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
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566", ec2: "http://localhost:4566" }],
});
TS

# ---------- base / step1：四种身份 ----------
cat > variants/base.ts <<TS
${PROVIDER_TS}

// logical name = "media-bucket"，未指定物理名 -> provider auto-name（带随机后缀）。
const media = new aws.s3.Bucket("media-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

// logical name = "data-bucket"，显式指定固定物理名 -> 放弃随机后缀。
const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform" },
}, { provider: localAws });

export const mediaLogical = "media-bucket";          // 你在代码里起的名字
export const mediaPhysical = media.bucket;           // physical name（auto-named）
export const mediaId = media.id;                     // physical ID（provider 返回）
export const mediaArn = media.arn;
export const dataPhysical = data.bucket;             // 固定物理名
TS

# ---------- step2-pre：replaceOnChanges 强制把 tag 变化当作替换（无 dbr） ----------
cat > variants/step2-pre.ts <<TS
${PROVIDER_TS}

const media = new aws.s3.Bucket("media-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

// 固定物理名 + replaceOnChanges：改 tag 会被强制当成 replace。
const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform", env: "staging" },
}, { provider: localAws, replaceOnChanges: ["tags"] });

export const mediaLogical = "media-bucket";
export const mediaPhysical = media.bucket;
export const mediaId = media.id;
export const mediaArn = media.arn;
export const dataPhysical = data.bucket;
TS

# ---------- step2：加 deleteBeforeReplace，先删后建避免同名冲突 ----------
cat > variants/step2.ts <<TS
${PROVIDER_TS}

const media = new aws.s3.Bucket("media-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform", env: "staging" },
}, { provider: localAws, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

export const mediaLogical = "media-bucket";
export const mediaPhysical = media.bucket;
export const mediaId = media.id;
export const mediaArn = media.arn;
export const dataPhysical = data.bucket;
TS

# ---------- step3：隐式依赖（tag 引用 output）与显式 dependsOn ----------
cat > variants/step3.ts <<TS
${PROVIDER_TS}

const media = new aws.s3.Bucket("media-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform", env: "staging" },
}, { provider: localAws, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

// 隐式依赖：tag 引用了 data.bucket（一个 Output），Pulumi 自动让 log 在 data 之后创建。
const log = new aws.s3.Bucket("log-bucket", {
  tags: { team: "platform", linkedTo: data.bucket },
}, { provider: localAws });

// 显式依赖：audit 与 log 没有数据引用，但用 dependsOn 强制顺序。
const audit = new aws.s3.Bucket("audit-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, dependsOn: [log] });

export const mediaLogical = "media-bucket";
export const mediaPhysical = media.bucket;
export const mediaId = media.id;
export const dataPhysical = data.bucket;
export const logPhysical = log.bucket;
export const auditPhysical = audit.bucket;
TS

# ---------- step4-noalias：把 media 改逻辑名为 assets（无 alias） ----------
cat > variants/step4-noalias.ts <<TS
${PROVIDER_TS}

// 仅把 logical name 从 "media-bucket" 改成 "assets-bucket"，未加 aliases。
const assets = new aws.s3.Bucket("assets-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform", env: "staging" },
}, { provider: localAws, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

const log = new aws.s3.Bucket("log-bucket", {
  tags: { team: "platform", linkedTo: data.bucket },
}, { provider: localAws });

const audit = new aws.s3.Bucket("audit-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, dependsOn: [log] });

export const assetsPhysical = assets.bucket;
export const dataPhysical = data.bucket;
export const logPhysical = log.bucket;
export const auditPhysical = audit.bucket;
TS

# ---------- step4：同样改名，但用 aliases 认领旧资源（零重建） ----------
cat > variants/step4.ts <<TS
${PROVIDER_TS}

// 改名 + aliases：告诉 Pulumi "assets-bucket 就是以前的 media-bucket"。
const assets = new aws.s3.Bucket("assets-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, aliases: [{ name: "media-bucket" }] });

const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform", env: "staging" },
}, { provider: localAws, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

const log = new aws.s3.Bucket("log-bucket", {
  tags: { team: "platform", linkedTo: data.bucket },
}, { provider: localAws });

const audit = new aws.s3.Bucket("audit-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, dependsOn: [log] });

export const assetsPhysical = assets.bucket;
export const dataPhysical = data.bucket;
export const logPhysical = log.bucket;
export const auditPhysical = audit.bucket;
TS

# ---------- step5：protect 防误删 ----------
cat > variants/step5.ts <<TS
${PROVIDER_TS}

const assets = new aws.s3.Bucket("assets-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, aliases: [{ name: "media-bucket" }] });

// protect: true -> destroy 时会被拦截。
const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform", env: "staging" },
}, { provider: localAws, replaceOnChanges: ["tags"], deleteBeforeReplace: true, protect: true });

const log = new aws.s3.Bucket("log-bucket", {
  tags: { team: "platform", linkedTo: data.bucket },
}, { provider: localAws });

const audit = new aws.s3.Bucket("audit-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, dependsOn: [log] });

export const assetsPhysical = assets.bucket;
export const dataPhysical = data.bucket;
TS

# ---------- step5-clean：移除 protect、用 ignoreChanges 忽略 tag 漂移，便于清理 ----------
cat > variants/step5-clean.ts <<TS
${PROVIDER_TS}

// ignoreChanges: ["tags"] -> 改了 tag 也不会产生 diff。
const assets = new aws.s3.Bucket("assets-bucket", {
  tags: { team: "platform", note: "changed-out-of-band" },
}, { provider: localAws, aliases: [{ name: "media-bucket" }], ignoreChanges: ["tags"] });

// 去掉 protect，便于随后 destroy。
const data = new aws.s3.Bucket("data-bucket", {
  bucket: "resources-lab-data",
  tags: { team: "platform", env: "staging" },
}, { provider: localAws, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

const log = new aws.s3.Bucket("log-bucket", {
  tags: { team: "platform", linkedTo: data.bucket },
}, { provider: localAws });

const audit = new aws.s3.Bucket("audit-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, dependsOn: [log] });

export const assetsPhysical = assets.bucket;
export const dataPhysical = data.bucket;
TS

# ---------- step6-pre：一套全新网络资源，ENI 不带安全组，且未注册 transform ----------
cat > variants/step6-pre.ts <<TS
${PROVIDER_TS}

// 一套小型网络：VPC + 子网。
const vpc = new aws.ec2.Vpc("app-vpc", {
  cidrBlock: "10.0.0.0/16",
  tags: { team: "platform" },
}, { provider: localAws });

const subnet = new aws.ec2.Subnet("app-subnet", {
  vpcId: vpc.id,
  cidrBlock: "10.0.1.0/24",
}, { provider: localAws });

// 一个"默认防火墙"安全组——稍后用 transform 在缺省时自动挂上它。
const defaultFw = new aws.ec2.SecurityGroup("default-fw", {
  vpcId: vpc.id,
  description: "default firewall for ENIs without an explicit security group",
}, { provider: localAws });

// 这块 ENI 故意不写 securityGroups，且当前没有注册任何 transform。
const eni = new aws.ec2.NetworkInterface("app-eni", {
  subnetId: subnet.id,
  privateIps: ["10.0.1.10"],
}, { provider: localAws });

export const vpcId = vpc.id;
export const defaultFwId = defaultFw.id;
export const eniSecurityGroups = eni.securityGroups;   // 还看不到 default-fw 的 id
TS

# ---------- step6：注册 stack transform，给没有安全组的 ENI 自动挂默认防火墙 ----------
cat > variants/step6.ts <<TS
${PROVIDER_TS}

const vpc = new aws.ec2.Vpc("app-vpc", {
  cidrBlock: "10.0.0.0/16",
  tags: { team: "platform" },
}, { provider: localAws });

const subnet = new aws.ec2.Subnet("app-subnet", {
  vpcId: vpc.id,
  cidrBlock: "10.0.1.0/24",
}, { provider: localAws });

const defaultFw = new aws.ec2.SecurityGroup("default-fw", {
  vpcId: vpc.id,
  description: "default firewall for ENIs without an explicit security group",
}, { provider: localAws });

// 关键：注册一个 stack transform。
// 任何 NetworkInterface 只要没有显式关联安全组，就自动挂上 default-fw。
pulumi.runtime.registerResourceTransform(args => {
  if (args.type === "aws:ec2/networkInterface:NetworkInterface") {
    const props: any = args.props;
    if (!props.securityGroups || props.securityGroups.length === 0) {
      props.securityGroups = [defaultFw.id];
      return { props, opts: args.opts };
    }
  }
  return undefined;
});

// 与 step6-pre 完全相同的 ENI 声明——这次 transform 会替它补上 default-fw。
const eni = new aws.ec2.NetworkInterface("app-eni", {
  subnetId: subnet.id,
  privateIps: ["10.0.1.10"],
}, { provider: localAws });

export const vpcId = vpc.id;
export const defaultFwId = defaultFw.id;
export const eniSecurityGroups = eni.securityGroups;   // 现在应包含 default-fw 的 id
TS

# 初始程序使用 base 变体。
cp variants/base.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull localstack/localstack:3 >/dev/null 2>&1 || true

# 启动 LocalStack 并等待健康检查通过，确保学员到达 step1 时模拟器已就绪。
echo "启动 LocalStack……"
docker compose up -d >/dev/null 2>&1 || true
for i in $(seq 1 60); do
  if curl -fs http://localhost:4566/_localstack/health >/dev/null 2>&1; then
    echo "LocalStack 已就绪。"
    break
  fi
  sleep 2
done

touch /tmp/.setup-done
echo "AWS / LocalStack resources lab is ready in /root/workspace"