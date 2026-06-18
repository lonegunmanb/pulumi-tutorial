#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-providers"
export SCENARIO_TITLE="Provider 抽象（纯本地）"
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

mkdir -p /root/workspace/variants /root/workspace/output
cd /root/workspace

cat > package.json <<'JSON'
{
  "name": "pulumi-providers-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
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
name: pulumi-providers
runtime: nodejs
description: Explore default vs explicit providers, the Any Terraform Provider, and dynamic providers — all locally.
YAML

# ---------- step1-default：default provider ----------
cat > variants/step1-default.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";

// 没有指定 { provider }，于是用的是 random 的 default provider。
const pet = new random.RandomPet("site-name", { length: 2 });

export const usingProvider = "default";
export const petName = pet.id;
TS

# ---------- step1-explicit：explicit provider ----------
cat > variants/step1-explicit.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";

// explicit provider：它本身就是一个资源，配置在声明时传入。
// random 没有有意义的全局配置，但用法与 aws.Provider / kubernetes.Provider 完全一致。
const explicitRandom = new random.Provider("explicit-random", {});

const pet = new random.RandomPet("site-name", { length: 2 }, { provider: explicitRandom });

export const usingProvider = "explicit";
export const petName = pet.id;
TS

# ---------- step2：Any Terraform Provider（hashicorp/local） ----------
cat > variants/step2.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";
// 这个包没有官方 Pulumi SDK，是用 `pulumi package add terraform-provider hashicorp/local` 现生成的本地 SDK。
import * as local from "@pulumi/local";

const pet = new random.RandomPet("site-name", { length: 2 });

// 用一个 Terraform provider 在本地写出一个文件——驱动它的却是 Pulumi。
const file = new local.File("greeting-file", {
  filename: "/root/workspace/output/greeting.txt",
  content: pulumi.interpolate`Hello from ${pet.id}, written by a Terraform provider, driven by Pulumi.\n`,
});

export const petName = pet.id;
export const filePath = file.filename;
TS

# ---------- step3：Dynamic Provider（内联 CRUD） ----------
cat > variants/step3.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";

// 内联实现一个 dynamic provider：你亲手写 create/update/delete。
// 演示里只做纯计算（不触碰外部系统），方便观察引擎调用 CRUD 的时机。
const greetingProvider: pulumi.dynamic.ResourceProvider = {
  async create(inputs) {
    return {
      id: `greeting-${Date.now()}`,
      outs: { message: inputs.message, shout: String(inputs.message).toUpperCase(), version: 1 },
    };
  },
  async update(id, olds, news) {
    return {
      outs: { message: news.message, shout: String(news.message).toUpperCase(), version: (olds.version ?? 1) + 1 },
    };
  },
  async delete(id, props) {
    // 真实场景在这里调用删除 API；演示里无需清理。
  },
};

class Greeting extends pulumi.dynamic.Resource {
  public readonly message!: pulumi.Output<string>;
  public readonly shout!: pulumi.Output<string>;
  public readonly version!: pulumi.Output<number>;
  constructor(name: string, message: pulumi.Input<string>, opts?: pulumi.CustomResourceOptions) {
    super(greetingProvider, name, { message, shout: undefined, version: undefined }, opts);
  }
}

const hello = new Greeting("hello", "hello pulumi");

export const message = hello.message;
export const shout = hello.shout;
export const version = hello.version;
TS

# ---------- step3-update：改属性触发 update ----------
cat > variants/step3-update.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";

const greetingProvider: pulumi.dynamic.ResourceProvider = {
  async create(inputs) {
    return {
      id: `greeting-${Date.now()}`,
      outs: { message: inputs.message, shout: String(inputs.message).toUpperCase(), version: 1 },
    };
  },
  async update(id, olds, news) {
    return {
      outs: { message: news.message, shout: String(news.message).toUpperCase(), version: (olds.version ?? 1) + 1 },
    };
  },
  async delete(id, props) {
  },
};

class Greeting extends pulumi.dynamic.Resource {
  public readonly message!: pulumi.Output<string>;
  public readonly shout!: pulumi.Output<string>;
  public readonly version!: pulumi.Output<number>;
  constructor(name: string, message: pulumi.Input<string>, opts?: pulumi.CustomResourceOptions) {
    super(greetingProvider, name, { message, shout: undefined, version: undefined }, opts);
  }
}

// 只改了 message —— 引擎会调用 update（而不是 replace）。
const hello = new Greeting("hello", "providers are awesome");

export const message = hello.message;
export const shout = hello.shout;
export const version = hello.version;
TS

# 初始程序使用 step1-default 变体。
cp variants/step1-default.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true

# 预先把 hashicorp/local 这个 Terraform provider 拉成本地 SDK（step2 用），
# 这样课堂上重复执行也很快，且能在 init 阶段提前暴露网络问题。
pulumi package add terraform-provider hashicorp/local >/dev/null 2>&1 || true
npm install --no-audit --no-fund >/dev/null 2>&1 || true

pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Providers lab is ready in /root/workspace"
