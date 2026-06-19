#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-secrets-handling"
export SCENARIO_TITLE="Secrets 机密处理：AWS / LocalStack 版"
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
    container_name: pulumi-secrets-localstack
    ports:
      - "4566:4566"
    environment:
      - SERVICES=secretsmanager,sts
      - DEFAULT_REGION=us-east-1
      - EAGER_SERVICE_LOADING=1
    deploy:
      resources:
        limits:
          memory: 1536M
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-secrets-handling-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@pulumi/aws": "^7.0.0",
    "@pulumi/pulumi": "^3.0.0",
    "@pulumi/random": "^4.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "ts-node": "^10.9.2",
    "typescript": "^5.0.0"
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: pulumi-secrets-handling
runtime: nodejs
description: Explore Pulumi secrets handling with the AWS provider against LocalStack.
YAML

# ---------- 共享的 provider 片段（只写字段那一步会复用） ----------
read -r -d '' PROVIDER_TS <<'TS'
import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

// 用显式配置的 provider 把所有 AWS 调用指向本地 LocalStack，而非真实 AWS。
const localAws = new aws.Provider("localstack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{
    sts: "http://localhost:4566",
    secretsmanager: "http://localhost:4566",
  }],
});
TS

# ---------- step1：Secret 配置与遮蔽（纯配置，无需 LocalStack） ----------
cat > variants/step1.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();

// require：明文配置，正常显示
const region = config.require("region");

// requireSecret：从配置读取机密；用 secret 版 getter 确保机密性沿数据流传播
const dbPassword = config.requireSecret("dbPassword");

// 派生值：把 secret 拼进连接串 —— 结果自动继承 secret 标记
const connectionString = dbPassword.apply(
  pw => `postgres://admin:${pw}@db.${region}.local:5432/app`,
);

export const regionOut = region;                  // 明文 → 正常显示
export const exportedPassword = dbPassword;        // secret → 显示为 [secret]
export const connectionStringOut = connectionString; // 派生 secret → 同样 [secret]
TS

# ---------- step2：程序内创建 secret 与机密传播（纯 random，无需 LocalStack） ----------
cat > variants/step2.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";

// 方式一：pulumi.secret —— 把一个普通值显式包成 secret
const wrapped = pulumi.secret("manually-wrapped-token");

// 方式二：从配置读 secret，再 apply 派生 —— 派生结果仍是 secret
const config = new pulumi.Config();
const apiKey = config.requireSecret("apiKey");
const authHeader = apiKey.apply(k => `Bearer ${k}`);

// random.RandomPassword：生成的密码放在 result 里，provider 默认已把它标记为 secret
const password = new random.RandomPassword("db-password", {
  length: 20,
  special: true,
});

export const wrappedValue = wrapped;          // [secret]
export const authHeaderOut = authHeader;      // [secret]（由 apiKey 派生而来）
export const generatedPassword = password.result; // [secret]（RandomPassword 默认机密）
TS

# ---------- step3：additionalSecretOutputs 与资源 ID 陷阱（纯 random） ----------
cat > variants/step3.ts <<'TS'
import * as random from "@pulumi/random";

// ❌ RandomString：result 同时也是它的 id —— physical ID 永远以明文进 state！
// 即便把 result 标成 secret，生成的随机串仍会藏在 id 里泄漏。
const insecure = new random.RandomString("insecure-token", {
  length: 16,
  special: false,
}, { additionalSecretOutputs: ["result"] });

// ✅ RandomPassword：result 不是 id，标成 secret 后在 state 各处都加密。
const secure = new random.RandomPassword("secure-token", {
  length: 16,
}, { additionalSecretOutputs: ["result"] });

export const insecureId = insecure.id;         // 明文，等于那个随机串（已泄漏）
export const insecureResult = insecure.result; // [secret]，但 id 已经暴露了同样的值
export const secureResult = secure.result;     // [secret]，且 id 不含机密
TS

# ---------- step4：只写字段（write-only），需要 LocalStack ----------
cat > variants/step4-v1.ts <<TS
${PROVIDER_TS}

// Secrets Manager 的密钥容器（只存元数据，不含值本身）。
const secret = new aws.secretsmanager.Secret("app-secret", {
  name: "app/db-password",
  recoveryWindowInDays: 0, // 实验环境立即删除，省去恢复窗口
}, { provider: localAws });

// 只写字段：secretStringWo 写入云端但永不被读回；
// secretStringWoVersion 受 Pulumi 完整生命周期管理，用来控制何时重新下发。
const version = new aws.secretsmanager.SecretVersion("app-secret-version", {
  secretId: secret.id,
  secretStringWo: "initial-write-only-secret",
  secretStringWoVersion: 1,
}, { provider: localAws });

export const secretArn = secret.arn;
export const versionId = version.versionId;
export const hasWriteOnly = version.hasSecretStringWo; // 是否设置过只写值
TS

# step4 变体 A：只改 secretStringWo 的值，但**不**递增版本 —— Pulumi 不应触发更新。
cat > variants/step4-same-version.ts <<TS
${PROVIDER_TS}

const secret = new aws.secretsmanager.Secret("app-secret", {
  name: "app/db-password",
  recoveryWindowInDays: 0,
}, { provider: localAws });

const version = new aws.secretsmanager.SecretVersion("app-secret-version", {
  secretId: secret.id,
  secretStringWo: "changed-but-version-unchanged", // 值变了
  secretStringWoVersion: 1,                          // 版本没变 → 不会更新
}, { provider: localAws });

export const secretArn = secret.arn;
export const versionId = version.versionId;
export const hasWriteOnly = version.hasSecretStringWo;
TS

# step4 变体 B：递增版本号 —— 这才会真正触发只写值的更新。
cat > variants/step4-bumped.ts <<TS
${PROVIDER_TS}

const secret = new aws.secretsmanager.Secret("app-secret", {
  name: "app/db-password",
  recoveryWindowInDays: 0,
}, { provider: localAws });

const version = new aws.secretsmanager.SecretVersion("app-secret-version", {
  secretId: secret.id,
  secretStringWo: "rotated-write-only-secret", // 新值
  secretStringWoVersion: 2,                     // 递增 → 触发更新
}, { provider: localAws });

export const secretArn = secret.arn;
export const versionId = version.versionId;
export const hasWriteOnly = version.hasSecretStringWo;
TS

# 初始程序使用 step1 变体（纯配置）。
cp variants/step1.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true

# 预置一个明文配置，机密配置留给学员在 step1 亲手设置。
pulumi config set region us-east-1 >/dev/null 2>&1 || true

docker pull localstack/localstack:3 >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "[$(date +%Y-%m-%dT%H:%M:%S)] 初始化完成，已写入 /tmp/.setup-done"
