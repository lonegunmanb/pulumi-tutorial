#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-inputs-outputs"
export SCENARIO_TITLE="Inputs 与 Outputs：AWS / MiniStack 版"
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
    container_name: pulumi-inputs-outputs-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-inputs-outputs-aws-lab",
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
name: pulumi-inputs-outputs
runtime: nodejs
description: Explore Pulumi Inputs and Outputs with the AWS provider against MiniStack.
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
  endpoints: [{ s3: "http://localhost:4566", sts: "http://localhost:4566" }],
});
TS

# ---------- base / step1：Output 不是普通值 ----------
cat > variants/base.ts <<TS
${PROVIDER_TS}

// 一个最普通的 S3 Bucket。它的 id / arn / bucket 都是 Output —— 资源建好才知道真实值。
const dataBucket = new aws.s3.Bucket("data-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

// ❌ 直接把 Output 当字符串用：日志里看到的不是真实值，而是 Output 对象 / 一条警告。
console.log("直接打印 bucket.id =>", dataBucket.id);

// ✅ 用 apply：等值就绪后回调才被调用，拿到的是真实字符串。
dataBucket.id.apply(id => console.log("apply 拿到的真实 bucket id =>", id));

export const bucketId = dataBucket.id;        // physical ID（Output）
export const bucketName = dataBucket.bucket;  // physical name（Output）
export const bucketArn = dataBucket.arn;      // ARN（Output）
TS

# ---------- step2：用 apply 变换单个 Output ----------
cat > variants/step2.ts <<TS
${PROVIDER_TS}

const dataBucket = new aws.s3.Bucket("data-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

// apply：基于 arn 这个 Output 算出一个全新的 Output<string>，依赖关系自动继承。
const arnUpper = dataBucket.arn.apply(arn => arn.toUpperCase());

// apply：把 bucket 名拼成一个伪 endpoint（演示在回调里自由运算真实值）。
const endpoint = dataBucket.bucket.apply(name => \`http://localhost:4566/\${name}\`);

export const bucketArn = dataBucket.arn;
export const bucketArnUpper = arnUpper;   // 仍然是 Output<string>
export const bucketEndpoint = endpoint;
TS

# ---------- step3：Output→Input 与依赖（隐式 + 显式 dependsOn） ----------
cat > variants/step3.ts <<TS
${PROVIDER_TS}

const dataBucket = new aws.s3.Bucket("data-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

// 把 dataBucket 的 Output（bucket 名）当作 logBucket 的 Input（写进 tag）。
// Pulumi 自动记下 "log-bucket 依赖 data-bucket"，保证先建 data-bucket。
const logBucket = new aws.s3.Bucket("log-bucket", {
  tags: { team: "platform", linkedTo: dataBucket.bucket },
}, { provider: localAws });

// auditBucket 与 logBucket 没有数据引用，但用 dependsOn 强制时序。
const auditBucket = new aws.s3.Bucket("audit-bucket", {
  tags: { team: "platform" },
}, { provider: localAws, dependsOn: [logBucket] });

export const dataName = dataBucket.bucket;
export const logName = logBucket.bucket;
export const auditName = auditBucket.bucket;
TS

# ---------- step4：用 all 组合多个 Output ----------
cat > variants/step4.ts <<TS
${PROVIDER_TS}

const dataBucket = new aws.s3.Bucket("data-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

const logBucket = new aws.s3.Bucket("log-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

// all：等两个桶的 Output 都就绪，拼成一条字符串（结果仍是 Output）。
export const summary = pulumi
  .all([dataBucket.bucket, logBucket.bucket])
  .apply(([data, log]) => \`data=\${data}; log=\${log}\`);

// all：组合成一个对象。
export const inventory = pulumi
  .all([dataBucket.arn, logBucket.arn])
  .apply(([dataArn, logArn]) => ({ dataArn, logArn }));
TS

# ---------- step5：Output helpers（concat / interpolate / jsonStringify） ----------
cat > variants/step5.ts <<TS
${PROVIDER_TS}

const dataBucket = new aws.s3.Bucket("data-bucket", {
  tags: { team: "platform" },
}, { provider: localAws });

const key = "config/app.json";

// concat：把字符串与 Output 依次拼接成 Output<string>。
export const s3UrlConcat = pulumi.concat("s3://", dataBucket.bucket, "/", key);

// interpolate：模板字面量里直接写 Output，最贴近原生写法。
export const s3UrlInterp = pulumi.interpolate\`s3://\${dataBucket.bucket}/\${key}\`;

// jsonStringify + interpolate：把含 Output 的结构整体序列化成一段 policy JSON 字符串。
export const policyJson = pulumi.jsonStringify({
  Version: "2012-10-17",
  Statement: [
    {
      Effect: "Allow",
      Principal: "*",
      Action: "s3:GetObject",
      Resource: pulumi.interpolate\`\${dataBucket.arn}/*\`,
    },
  ],
});
TS

# 初始程序使用 base 变体。
cp variants/base.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "[$(date +%Y-%m-%dT%H:%M:%S)] 初始化完成，已写入 /tmp/.setup-done"
