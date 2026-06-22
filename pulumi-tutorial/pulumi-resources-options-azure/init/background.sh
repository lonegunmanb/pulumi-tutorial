#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-resources-options-azure"
export SCENARIO_TITLE="资源与精细控制：Azure / miniblue 版"
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
    container_name: pulumi-resources-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-resources-options-azure-lab",
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
name: pulumi-resources-options-azure
runtime: nodejs
description: Explore resource names, identity and options with the Azure (azurerm) provider against miniblue.
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

# ---------- base / step1：四种身份 ----------
cat > variants/base.ts <<TS
${PROVIDER_TS}

// logical name = "media-rg"，未指定物理名 -> provider auto-name（带随机后缀）。
const media = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

// logical name = "data-rg"，显式指定固定物理名 -> 放弃随机后缀。
const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

export const mediaLogical = "media-rg";       // 你在代码里起的名字
export const mediaPhysical = media.name;       // physical name（auto-named）
export const mediaId = media.id;               // physical ID（ARM resource ID）
export const dataPhysical = data.name;          // 固定物理名
TS

# ---------- step2-pre：replaceOnChanges 强制把 tag 变化当作替换（无 dbr） ----------
cat > variants/step2-pre.ts <<TS
${PROVIDER_TS}

const media = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

// 固定物理名 + replaceOnChanges：改 tag 会被强制当成 replace。
const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform", env: "staging" },
}, { provider: miniblue, replaceOnChanges: ["tags"] });

export const mediaLogical = "media-rg";
export const mediaPhysical = media.name;
export const mediaId = media.id;
export const dataPhysical = data.name;
TS

# ---------- step2：加 deleteBeforeReplace，先删后建避免同名冲突 ----------
cat > variants/step2.ts <<TS
${PROVIDER_TS}

const media = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform", env: "staging" },
}, { provider: miniblue, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

export const mediaLogical = "media-rg";
export const mediaPhysical = media.name;
export const mediaId = media.id;
export const dataPhysical = data.name;
TS

# ---------- step3：隐式依赖（tag 引用 output）与显式 dependsOn ----------
cat > variants/step3.ts <<TS
${PROVIDER_TS}

const media = new azure.core.ResourceGroup("media-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform", env: "staging" },
}, { provider: miniblue, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

// 隐式依赖：tag 引用了 data.name（一个 Output），Pulumi 自动让 log 在 data 之后创建。
const log = new azure.core.ResourceGroup("log-rg", {
  location,
  tags: { team: "platform", linkedTo: data.name },
}, { provider: miniblue });

// 显式依赖：audit 与 log 没有数据引用，但用 dependsOn 强制顺序。
const audit = new azure.core.ResourceGroup("audit-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, dependsOn: [log] });

export const mediaLogical = "media-rg";
export const mediaPhysical = media.name;
export const mediaId = media.id;
export const dataPhysical = data.name;
export const logPhysical = log.name;
export const auditPhysical = audit.name;
TS

# ---------- step4-noalias：把 media 改逻辑名为 assets（无 alias） ----------
cat > variants/step4-noalias.ts <<TS
${PROVIDER_TS}

// 仅把 logical name 从 "media-rg" 改成 "assets-rg"，未加 aliases。
const assets = new azure.core.ResourceGroup("assets-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform", env: "staging" },
}, { provider: miniblue, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

const log = new azure.core.ResourceGroup("log-rg", {
  location,
  tags: { team: "platform", linkedTo: data.name },
}, { provider: miniblue });

const audit = new azure.core.ResourceGroup("audit-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, dependsOn: [log] });

export const assetsPhysical = assets.name;
export const dataPhysical = data.name;
export const logPhysical = log.name;
export const auditPhysical = audit.name;
TS

# ---------- step4：同样改名，但用 aliases 认领旧资源（零重建） ----------
cat > variants/step4.ts <<TS
${PROVIDER_TS}

// 改名 + aliases：告诉 Pulumi "assets-rg 就是以前的 media-rg"。
const assets = new azure.core.ResourceGroup("assets-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, aliases: [{ name: "media-rg" }] });

const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform", env: "staging" },
}, { provider: miniblue, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

const log = new azure.core.ResourceGroup("log-rg", {
  location,
  tags: { team: "platform", linkedTo: data.name },
}, { provider: miniblue });

const audit = new azure.core.ResourceGroup("audit-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, dependsOn: [log] });

export const assetsPhysical = assets.name;
export const dataPhysical = data.name;
export const logPhysical = log.name;
export const auditPhysical = audit.name;
TS

# ---------- step5：protect 防误删 ----------
cat > variants/step5.ts <<TS
${PROVIDER_TS}

const assets = new azure.core.ResourceGroup("assets-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, aliases: [{ name: "media-rg" }] });

// protect: true -> destroy 时会被拦截。
const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform", env: "staging" },
}, { provider: miniblue, replaceOnChanges: ["tags"], deleteBeforeReplace: true, protect: true });

const log = new azure.core.ResourceGroup("log-rg", {
  location,
  tags: { team: "platform", linkedTo: data.name },
}, { provider: miniblue });

const audit = new azure.core.ResourceGroup("audit-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, dependsOn: [log] });

export const assetsPhysical = assets.name;
export const dataPhysical = data.name;
TS

# ---------- step5-clean：移除 protect、用 ignoreChanges 忽略 tag 漂移，便于清理 ----------
cat > variants/step5-clean.ts <<TS
${PROVIDER_TS}

// ignoreChanges: ["tags"] -> 改了 tag 也不会产生 diff。
const assets = new azure.core.ResourceGroup("assets-rg", {
  location,
  tags: { team: "platform", note: "changed-out-of-band" },
}, { provider: miniblue, aliases: [{ name: "media-rg" }], ignoreChanges: ["tags"] });

// 去掉 protect，便于随后 destroy。
const data = new azure.core.ResourceGroup("data-rg", {
  name: "resources-lab-data-rg",
  location,
  tags: { team: "platform", env: "staging" },
}, { provider: miniblue, replaceOnChanges: ["tags"], deleteBeforeReplace: true });

const log = new azure.core.ResourceGroup("log-rg", {
  location,
  tags: { team: "platform", linkedTo: data.name },
}, { provider: miniblue });

const audit = new azure.core.ResourceGroup("audit-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue, dependsOn: [log] });

export const assetsPhysical = assets.name;
export const dataPhysical = data.name;
TS

# ---------- step6-pre：一套全新网络资源，子网不带 NSG，且未注册 transform ----------
cat > variants/step6-pre.ts <<TS
${PROVIDER_TS}

const rg = new azure.core.ResourceGroup("net-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

// 一个"默认 NSG"——稍后用 transform 在缺省时自动关联到子网。
const defaultNsg = new azure.network.NetworkSecurityGroup("default-nsg", {
  resourceGroupName: rg.name,
  location,
}, { provider: miniblue });

// VNet 内联一个子网，故意不设置 securityGroup，且当前没有注册任何 transform。
const vnet = new azure.network.VirtualNetwork("app-vnet", {
  resourceGroupName: rg.name,
  location,
  addressSpaces: ["10.0.0.0/16"],
  subnets: [
    { name: "app-subnet", addressPrefixes: ["10.0.1.0/24"] },
  ],
}, { provider: miniblue });

export const defaultNsgId = defaultNsg.id;
export const vnetSubnets = vnet.subnets;   // 子网的 securityGroup 还是空的
TS

# ---------- step6：注册 stack transform，给没有 NSG 的内联子网自动关联默认 NSG ----------
cat > variants/step6.ts <<TS
${PROVIDER_TS}

const rg = new azure.core.ResourceGroup("net-rg", {
  location,
  tags: { team: "platform" },
}, { provider: miniblue });

const defaultNsg = new azure.network.NetworkSecurityGroup("default-nsg", {
  resourceGroupName: rg.name,
  location,
}, { provider: miniblue });

// 关键：注册一个 stack transform。
// 任何 VirtualNetwork 的内联子网只要没有关联 NSG，就自动关联 default-nsg。
pulumi.runtime.registerResourceTransform(args => {
  if (args.type === "azure:network/virtualNetwork:VirtualNetwork") {
    const props: any = args.props;
    if (Array.isArray(props.subnets)) {
      props.subnets = props.subnets.map((s: any) =>
        s.securityGroup ? s : { ...s, securityGroup: defaultNsg.id });
      return { props, opts: args.opts };
    }
  }
  return undefined;
});

// 与 step6-pre 完全相同的 VNet 声明——这次 transform 会替每个缺省子网补上 default-nsg。
const vnet = new azure.network.VirtualNetwork("app-vnet", {
  resourceGroupName: rg.name,
  location,
  addressSpaces: ["10.0.0.0/16"],
  subnets: [
    { name: "app-subnet", addressPrefixes: ["10.0.1.0/24"] },
  ],
}, { provider: miniblue });

export const defaultNsgId = defaultNsg.id;
export const vnetSubnets = vnet.subnets;   // 现在每个子网的 securityGroup = default-nsg 的 id
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
echo "Azure / miniblue resources lab is ready in /root/workspace"
