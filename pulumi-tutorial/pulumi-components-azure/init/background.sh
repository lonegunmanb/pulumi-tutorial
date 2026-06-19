#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-components-azure"
export SCENARIO_TITLE="ComponentResource 组件化：Azure / miniblue 版"
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
    image: ghcr.io/lonegunmanb/miniblue:sha-11ef0e8
    container_name: pulumi-components-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-components-azure-lab",
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
name: pulumi-components-azure
runtime: nodejs
description: Encapsulate Azure Storage Accounts into a SecureStorage ComponentResource against miniblue.
YAML

# ---------- 共享的 provider 片段（把 Azure 调用指向本地 miniblue） ----------
read -r -d '' PROVIDER_TS <<'TS'
import * as azure from "@pulumi/azure";
import * as pulumi from "@pulumi/pulumi";

// 用显式配置的 azurerm provider 把所有 Azure 调用指向本地 miniblue，而非真实 Azure。
const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

const location = "eastus";
TS

# ---------- 共享的组件定义（v1：子资源名 ${name}-logs / ${name}-data） ----------
read -r -d '' COMPONENT_TS <<'TS'
// SecureStorage：把"主存储账户 + 访问日志账户 + 强制标签"封装成一个组件。
// 两个 Storage Account 必须落在一个 Resource Group 里，所以组件顺带创建一个 RG 作为容器。
export interface SecureStorageArgs {
  team: pulumi.Input<string>;
}

export class SecureStorage extends pulumi.ComponentResource {
  public readonly accountName: pulumi.Output<string>;
  public readonly logsAccountName: pulumi.Output<string>;

  constructor(name: string, args: SecureStorageArgs, opts?: pulumi.ComponentResourceOptions) {
    // 类型名格式固定：<package>:index:<类名>，部署后不要再改。
    super("acme:index:SecureStorage", name, args, opts);

    // 组件强制注入的标签（团队的合规默认值）。
    const tags = { team: args.team, managedBy: "platform" };
    // 存储账户物理名只能是 3-24 位小写字母数字，这里从实例名推导出一个合法 slug。
    const slug = name.toLowerCase().replace(/[^a-z0-9]/g, "");

    // 容纳两个存储账户的资源组；子资源都设 parent: this，并用 ${name} 拼前缀，保证多实例不撞名。
    const rg = new azure.core.ResourceGroup(`${name}-rg`, { location, tags }, { parent: this });

    // 子资源 1：访问日志存储账户。
    const logs = new azure.storage.Account(`${name}-logs`, {
      name: `${slug}logs`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, { parent: this });

    // 子资源 2：主存储账户。
    const account = new azure.storage.Account(`${name}-data`, {
      name: `${slug}data`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, { parent: this });

    this.accountName = account.name;
    this.logsAccountName = logs.name;

    // 收尾：注册输出，标记组件构造完成。
    this.registerOutputs({
      accountName: account.name,
      logsAccountName: logs.name,
    });
  }
}
TS

# ---------- flat / step1：平铺资源，没有组件、没有层级 ----------
cat > variants/flat.ts <<TS
${PROVIDER_TS}

// 平铺写法：一个资源组 + 两个存储账户直接声明，彼此没有共同的父，state 是扁平的。
const tags = { team: "platform", managedBy: "platform" };

const rg = new azure.core.ResourceGroup("media-rg", { location, tags }, { provider: miniblue });

const logs = new azure.storage.Account("media-logs", {
  name: "medialogs",
  resourceGroupName: rg.name,
  location,
  accountTier: "Standard",
  accountReplicationType: "LRS",
  tags,
}, { provider: miniblue });

const account = new azure.storage.Account("media-data", {
  name: "mediadata",
  resourceGroupName: rg.name,
  location,
  accountTier: "Standard",
  accountReplicationType: "LRS",
  tags,
}, { provider: miniblue });

export const accountName = account.name;
export const logsAccountName = logs.name;
TS

# ---------- component / step2：封装成单个组件实例 ----------
cat > variants/component.ts <<TS
${PROVIDER_TS}

${COMPONENT_TS}

// 实例化组件和实例化普通资源一样：name + args + options。
// provider 用 providers（复数）传给组件，会下传给每个 parent: this 的子资源。
const media = new SecureStorage("media", { team: "platform" }, { providers: [miniblue] });

export const accountName = media.accountName;
export const logsAccountName = media.logsAccountName;
TS

# ---------- reuse / step3：同一个组件实例化两次 ----------
cat > variants/reuse.ts <<TS
${PROVIDER_TS}

${COMPONENT_TS}

// 复用：实例化两次，子资源名会分别带上各自的实例名前缀。
const media = new SecureStorage("media", { team: "platform" }, { providers: [miniblue] });
const backups = new SecureStorage("backups", { team: "platform" }, { providers: [miniblue] });

export const mediaAccountName = media.accountName;
export const mediaLogsName = media.logsAccountName;
export const backupsAccountName = backups.accountName;
export const backupsLogsName = backups.logsAccountName;
TS

# ---------- evolve-broken / step4-pre：在组件内给子资源改名，但没加 alias ----------
read -r -d '' COMPONENT_RENAMED_TS <<'TS'
export interface SecureStorageArgs {
  team: pulumi.Input<string>;
}

export class SecureStorage extends pulumi.ComponentResource {
  public readonly accountName: pulumi.Output<string>;
  public readonly logsAccountName: pulumi.Output<string>;

  constructor(name: string, args: SecureStorageArgs, opts?: pulumi.ComponentResourceOptions) {
    super("acme:index:SecureStorage", name, args, opts);

    const tags = { team: args.team, managedBy: "platform" };
    const slug = name.toLowerCase().replace(/[^a-z0-9]/g, "");

    const rg = new azure.core.ResourceGroup(`${name}-rg`, { location, tags }, { parent: this });

    // 把日志账户的 logical name 从 ${name}-logs 改成 ${name}-access-logs（没有 alias）。
    const logs = new azure.storage.Account(`${name}-access-logs`, {
      name: `${slug}logs`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, { parent: this });

    const account = new azure.storage.Account(`${name}-data`, {
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

cat > variants/evolve-broken.ts <<TS
${PROVIDER_TS}

${COMPONENT_RENAMED_TS}

const media = new SecureStorage("media", { team: "platform" }, { providers: [miniblue] });
const backups = new SecureStorage("backups", { team: "platform" }, { providers: [miniblue] });

export const mediaAccountName = media.accountName;
export const mediaLogsName = media.logsAccountName;
export const backupsAccountName = backups.accountName;
export const backupsLogsName = backups.logsAccountName;
TS

# ---------- evolve-fixed / step4：同样改名，但用 aliases 认领旧子资源（零重建） ----------
read -r -d '' COMPONENT_ALIASED_TS <<'TS'
export interface SecureStorageArgs {
  team: pulumi.Input<string>;
}

export class SecureStorage extends pulumi.ComponentResource {
  public readonly accountName: pulumi.Output<string>;
  public readonly logsAccountName: pulumi.Output<string>;

  constructor(name: string, args: SecureStorageArgs, opts?: pulumi.ComponentResourceOptions) {
    super("acme:index:SecureStorage", name, args, opts);

    const tags = { team: args.team, managedBy: "platform" };
    const slug = name.toLowerCase().replace(/[^a-z0-9]/g, "");

    const rg = new azure.core.ResourceGroup(`${name}-rg`, { location, tags }, { parent: this });

    // 改名 + aliases：告诉 Pulumi "${name}-access-logs 就是以前的 ${name}-logs"。
    const logs = new azure.storage.Account(`${name}-access-logs`, {
      name: `${slug}logs`,
      resourceGroupName: rg.name,
      location,
      accountTier: "Standard",
      accountReplicationType: "LRS",
      tags,
    }, {
      parent: this,
      aliases: [{ name: `${name}-logs` }],
    });

    const account = new azure.storage.Account(`${name}-data`, {
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

cat > variants/evolve-fixed.ts <<TS
${PROVIDER_TS}

${COMPONENT_ALIASED_TS}

const media = new SecureStorage("media", { team: "platform" }, { providers: [miniblue] });
const backups = new SecureStorage("backups", { team: "platform" }, { providers: [miniblue] });

export const mediaAccountName = media.accountName;
export const mediaLogsName = media.logsAccountName;
export const backupsAccountName = backups.accountName;
export const backupsLogsName = backups.logsAccountName;
TS

# 初始程序使用 flat 变体。
cp variants/flat.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ghcr.io/lonegunmanb/miniblue:sha-11ef0e8 >/dev/null 2>&1 || true

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
echo "Azure / miniblue components lab is ready in /root/workspace"
