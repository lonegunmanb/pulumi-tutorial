#!/usr/bin/env bash
set -euo pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-stash"
export SCENARIO_TITLE="Stash 状态暂存：纯本地实验"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

rm -f /tmp/.setup-done
mkdir -p /root/workspace

# 安装 Pulumi、Node.js 与共享工具。
bash /root/setup-common.sh
export PATH="$HOME/.pulumi/bin:$PATH"

ensure_pulumi_stash_version() {
  local version major rest minor

  if ! command -v pulumi >/dev/null 2>&1; then
    curl -fsSL https://get.pulumi.com | sh >/dev/null
    export PATH="$HOME/.pulumi/bin:$PATH"
    return
  fi

  version="$(pulumi version | sed -E 's/^v//; s/[+-].*$//')"
  major="${version%%.*}"
  rest="${version#*.}"
  minor="${rest%%.*}"

  if [ "${major:-0}" -lt 3 ] || { [ "${major:-0}" -eq 3 ] && [ "${minor:-0}" -lt 208 ]; }; then
    curl -fsSL https://get.pulumi.com | sh >/dev/null
    export PATH="$HOME/.pulumi/bin:$PATH"
  fi
}

ensure_pulumi_stash_version

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi

mkdir -p /root/workspace/variants
cd /root/workspace

cat > package.json <<'JSON'
{
  "name": "pulumi-stash-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@pulumi/pulumi": "^3.208.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: pulumi-stash
runtime: nodejs
description: Explore the built-in Pulumi Stash resource with a local backend.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const releaseLabel = config.get("releaseLabel") ?? "release-001";

const release = new pulumi.Stash("release-label", {
  input: releaseLabel,
});

export const currentRelease = release.input;
export const stableRelease = release.output;
TS

cat > variants/complex-secret.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const releaseLabel = config.get("releaseLabel") ?? "release-001";

const release = new pulumi.Stash("release-label", {
  input: releaseLabel,
});

const metadata = new pulumi.Stash("deployment-metadata", {
  input: {
    project: pulumi.getProject(),
    stack: pulumi.getStack(),
    releaseLabel,
    services: ["api", "worker"],
    tags: {
      owner: "platform",
      tier: "tutorial",
    },
  },
});

const apiToken = new pulumi.Stash("api-token", {
  input: pulumi.secret("token-from-stash-lab"),
});

export const currentRelease = release.input;
export const stableRelease = release.output;
export const currentMetadata = metadata.input;
export const initialMetadata = metadata.output;
export const stashedToken = apiToken.output;
TS

cat > variants/empty.ts <<'TS'
export const note = "The program no longer declares any Stash resources.";
TS

npm install --no-audit --no-fund >/dev/null 2>&1
pulumi login --local >/dev/null 2>&1
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1
pulumi config set releaseLabel release-001 >/dev/null 2>&1

touch /tmp/.setup-done
echo "[$(date +%Y-%m-%dT%H:%M:%S)] 初始化完成，已写入 /tmp/.setup-done"