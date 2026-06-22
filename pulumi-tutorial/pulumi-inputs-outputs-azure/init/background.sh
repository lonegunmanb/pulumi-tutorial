#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-inputs-outputs-azure"
export SCENARIO_TITLE="Inputs 与 Outputs：Azure / miniblue 版"
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

apt-get install -y jq openssl >/dev/null 2>&1 || true
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
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-6d934ae
    container_name: pulumi-inputs-outputs-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-inputs-outputs-azure-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
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

cat > Pulumi.yaml <<'YAML'
name: pulumi-inputs-outputs-azure
runtime: nodejs
description: Explore Pulumi Inputs and Outputs with the Azure (azurerm) provider against miniblue.
YAML

# ---------- 共享的 provider 片段（指向本地 miniblue） ----------
read -r -d '' PROVIDER_TS <<'TS'
import * as azure from "@pulumi/azure";
import * as pulumi from "@pulumi/pulumi";

// 用显式配置的 azurerm provider 把所有 Azure 调用指向本地 miniblue，而非真实 Azure。
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

const location = "eastus";
TS

# ---------- base / step1：Output 不是普通值 ----------
cat > variants/base.ts <<TS
${PROVIDER_TS}

// 一个最普通的 Resource Group。它的 id / name 都是 Output —— 资源建好才知道真实值。
const dataRg = new azure.core.ResourceGroup("data-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

// ❌ 直接把 Output 当字符串用：日志里看到的不是真实值，而是 Output 对象 / 一条警告。
console.log("直接打印 rg.id =>", dataRg.id);

// ✅ 用 apply：等值就绪后回调才被调用，拿到的是真实字符串。
dataRg.id.apply(id => console.log("apply 拿到的真实 resource id =>", id));

export const rgId = dataRg.id;     // physical ID（ARM resource ID，Output）
export const rgName = dataRg.name;  // physical name（Output）
TS

# ---------- step2：用 apply 变换单个 Output ----------
cat > variants/step2.ts <<TS
${PROVIDER_TS}

const dataRg = new azure.core.ResourceGroup("data-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

// apply：基于 id 这个 Output 算出一个全新的 Output<string>，依赖关系自动继承。
const idUpper = dataRg.id.apply(id => id.toUpperCase());

// apply：把 name 拼成一个伪 portal 链接（演示在回调里自由运算真实值）。
const portalLink = dataRg.name.apply(name => \`https://portal.azure.com/#resource/resourceGroups/\${name}\`);

export const rgId = dataRg.id;
export const rgIdUpper = idUpper;   // 仍然是 Output<string>
export const portalHint = portalLink;
TS

# ---------- step3：Output→Input 与依赖（隐式 + 显式 dependsOn） ----------
cat > variants/step3.ts <<TS
${PROVIDER_TS}

const dataRg = new azure.core.ResourceGroup("data-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

// 把 dataRg 的 Output（name）当作 logRg 的 Input（写进 tag）。
// Pulumi 自动记下 "log-rg 依赖 data-rg"，保证先建 data-rg。
const logRg = new azure.core.ResourceGroup("log-rg", {
  location,
  tags: { team: "platform", linkedTo: dataRg.name },
}, { provider: miniblue });

// auditRg 与 logRg 没有数据引用，但用 dependsOn 强制时序。
const auditRg = new azure.core.ResourceGroup("audit-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, dependsOn: [logRg] });

export const dataName = dataRg.name;
export const logName = logRg.name;
export const auditName = auditRg.name;
TS

# ---------- step4：用 all 组合多个 Output ----------
cat > variants/step4.ts <<TS
${PROVIDER_TS}

const dataRg = new azure.core.ResourceGroup("data-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

const logRg = new azure.core.ResourceGroup("log-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

// all：等两个组的 Output 都就绪，拼成一条字符串（结果仍是 Output）。
export const summary = pulumi
  .all([dataRg.name, logRg.name])
  .apply(([data, log]) => \`data=\${data}; log=\${log}\`);

// all：组合成一个对象。
export const inventory = pulumi
  .all([dataRg.id, logRg.id])
  .apply(([dataId, logId]) => ({ dataId, logId }));
TS

# ---------- step5：Output helpers（concat / interpolate / jsonStringify） ----------
cat > variants/step5.ts <<TS
${PROVIDER_TS}

const dataRg = new azure.core.ResourceGroup("data-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

const container = "app-config";

// concat：把字符串与 Output 依次拼接成 Output<string>。
export const pathConcat = pulumi.concat("azrm://", dataRg.name, "/", container);

// interpolate：模板字面量里直接写 Output，最贴近原生写法。
export const pathInterp = pulumi.interpolate\`azrm://\${dataRg.name}/\${container}\`;

// jsonStringify + interpolate：把含 Output 的结构整体序列化成一段 role assignment JSON 字符串。
export const roleAssignmentJson = pulumi.jsonStringify({
  scope: pulumi.interpolate\`\${dataRg.id}/providers/Microsoft.Authorization\`,
  roleDefinition: "Reader",
  principalType: "ServicePrincipal",
});
TS

# 初始程序使用 base 变体。
cp variants/base.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ghcr.io/lonegunmanb/miniblue:sha-6d934ae >/dev/null 2>&1 || true

# 启动 miniblue 并等待 metadata 端口就绪。
docker compose up -d >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  curl -sk "https://localhost:4567/metadata/endpoints?api-version=2019-05-01" >/dev/null 2>&1 && break
  sleep 2
done

# 导出 miniblue 证书并加入系统信任库（azurerm provider 是 Go 二进制，使用系统 CA）。
openssl s_client -connect localhost:4567 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 > /usr/local/share/ca-certificates/miniblue.crt 2>/dev/null || true
update-ca-certificates >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "[$(date +%Y-%m-%dT%H:%M:%S)] 初始化完成，已写入 /tmp/.setup-done"
