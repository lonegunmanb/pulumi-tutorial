#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-config"
export SCENARIO_TITLE="Configuration 配置：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
# 让 ts-node 只转译、不做类型检查：避免对 @pulumi/aws 庞大的 .d.ts 做全量类型检查而吃掉 1GB+ 内存被 OOM 杀掉。
export TS_NODE_TRANSPILE_ONLY=1

rm -f /tmp/.setup-done
mkdir -p /root/workspace

# 给小内存的实验机加一块 swap 作为安全垫，缓解 pulumi up 的内存峰值（尽力而为，容器内 swapon 可能不被允许，失败也无妨）。
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null || true
  chmod 600 /swapfile 2>/dev/null || true
  mkswap /swapfile >/dev/null 2>&1 || true
  swapon /swapfile >/dev/null 2>&1 || true
fi

# 安装 Pulumi、Node.js 与共享工具（尽力而为，单步失败不影响后续）。
bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi
if ! grep -q 'TS_NODE_TRANSPILE_ONLY' /root/.bashrc 2>/dev/null; then
  echo 'export TS_NODE_TRANSPILE_ONLY=1' >> /root/.bashrc
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
    container_name: pulumi-config-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-config-aws-lab",
  "version": "1.0.0",
  "private": true,
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

# 开启 ts-node transpileOnly：跳过类型检查，大幅降低运行时内存（避免 @pulumi/aws 类型检查导致的 OOM）。
# 使用 CommonJS（而非 ESM），以便 @pulumi/aws/s3 这类“子模块目录”能被正常解析（ESM 不允许导入目录）。
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "strict": true,
    "target": "es2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "ts-node": {
    "transpileOnly": true
  }
}
JSON

cat > Pulumi.yaml <<'YAML'
name: pulumi-config
runtime: nodejs
description: Drive AWS resources from Pulumi configuration against MiniStack.
config:
  owner: platform-team
YAML

# ---------- 共享的 provider 片段（每个变体都会复用） ----------
read -r -d '' PROVIDER_TS <<'TS'
import * as pulumi from "@pulumi/pulumi";
// 只按子模块导入，避免 `import * as aws from "@pulumi/aws"` 把整个 AWS SDK
// （上千个资源类）全部加载进 Node 堆里——那会吞掉 1GB+ 内存，
// 在小内存环境（如 Killercoda VM）里会被内核 OOM 杀掉。
import * as s3 from "@pulumi/aws/s3";
import { Provider } from "@pulumi/aws/provider";

// 显式构造 provider，把所有 AWS 调用指向本地 MiniStack（而非真实 AWS）。
// 注意：显式 new 出来的 provider 不会读取 Stack 配置文件里的 aws:region，
// region 必须在这里直接给出——这正呼应正文 5A.9 的结论。
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
TS

# ---------- base / step1 / step2：require / get / 类型化 getter / 命名空间 ----------
cat > variants/base.ts <<TS
${PROVIDER_TS}

// 从配置里读取程序需要的值——而不是硬编码。
const config = new pulumi.Config();
const prefix = config.require("bucketPrefix");          // 必填：缺失就报错
const count = config.getNumber("bucketCount") ?? 1;     // 可选：缺失则用默认值 1

// 读取 aws 命名空间下的键（aws:region）。
// 我们只是把它当作一个标签值来"展示配置值"，provider 本身用的是上面写死的 region。
const awsConfig = new pulumi.Config("aws");
const region = awsConfig.get("region") ?? "us-east-1";

// 按配置的数量创建若干 S3 Bucket，名字带上配置的前缀。
const buckets: s3.Bucket[] = [];
for (let i = 0; i < count; i++) {
  buckets.push(new s3.Bucket(\`\${prefix}-bucket-\${i}\`, {
    tags: { team: "platform", configuredRegion: region },
  }, { provider: localAws }));
}

export const bucketCount = count;
export const configuredRegion = region;
export const bucketNames = pulumi.all(buckets.map(b => b.bucket));
TS

# ---------- step3：结构化配置（--path）与 requireObject ----------
cat > variants/step3.ts <<TS
${PROVIDER_TS}

const config = new pulumi.Config();
const prefix = config.require("bucketPrefix");
const count = config.getNumber("bucketCount") ?? 1;

// 结构化配置：requireObject 返回的是一个"普通对象"，不是 Config 实例，
// 所以下面用标准属性访问取嵌套值（呼应正文 5A.7 的陷阱提示）。
interface Tags {
  team: string;
  env: string;
  replicas: number;   // --path 设的整数会被存成 number
}
const tags = config.requireObject<Tags>("tags");

const buckets: s3.Bucket[] = [];
for (let i = 0; i < count; i++) {
  buckets.push(new s3.Bucket(\`\${prefix}-bucket-\${i}\`, {
    tags: {
      team: tags.team,
      env: tags.env,
      replicas: String(tags.replicas),   // tag 值必须是字符串
    },
  }, { provider: localAws }));
}

export const tagsFromConfig = tags;
export const bucketNames = pulumi.all(buckets.map(b => b.bucket));
TS

# ---------- step4：机密配置（--secret / requireSecret） ----------
cat > variants/step4.ts <<TS
${PROVIDER_TS}

const config = new pulumi.Config();
const prefix = config.require("bucketPrefix");

// 机密配置：requireSecret 返回一个 Output，携带"机密性"。
// 它在 stack output 里会被遮蔽成 [secret]，序列化进 state 时也会被加密。
const dbPassword = config.requireSecret("dbPassword");

const bucket = new s3.Bucket(\`\${prefix}-bucket-0\`, {
  tags: { team: "platform" },
}, { provider: localAws });

export const bucketName = bucket.bucket;
export const dbPasswordOut = dbPassword;
TS

# ---------- step5：同一套程序、多个 Stack（含项目级 owner 默认值） ----------
cat > variants/step5.ts <<TS
${PROVIDER_TS}

const config = new pulumi.Config();
const prefix = config.require("bucketPrefix");
const count = config.getNumber("bucketCount") ?? 1;
const owner = config.require("owner");   // 来自项目级 Pulumi.yaml 的默认值，可被 Stack 覆盖
const awsConfig = new pulumi.Config("aws");
const region = awsConfig.get("region") ?? "us-east-1";

const buckets: s3.Bucket[] = [];
for (let i = 0; i < count; i++) {
  buckets.push(new s3.Bucket(\`\${prefix}-bucket-\${i}\`, {
    tags: { owner, configuredRegion: region },
  }, { provider: localAws }));
}

export const stackPrefix = prefix;
export const bucketCount = count;
export const ownerName = owner;
export const configuredRegion = region;
export const bucketNames = pulumi.all(buckets.map(b => b.bucket));
TS

# ---------- step6：组件配置（组件从自己的命名空间 "app" 读配置） ----------
cat > variants/step6.ts <<TS
${PROVIDER_TS}

// 一个可复用组件：它从自己的命名空间 "app" 读取配置，
// 而不是依赖宿主项目的键——这样组件作者圈出的键空间与宿主项目互不干扰。
class BucketFleet extends pulumi.ComponentResource {
  public readonly bucketNames: pulumi.Output<string[]>;

  constructor(name: string, args: { provider: Provider }, opts?: pulumi.ComponentResourceOptions) {
    // 这里的 "app" 是资源类型 token（<包>:<模块>:<类型>），只用于生成 URN 前缀、标识资源类型，
    // 与下面 new pulumi.Config("app") 读取的配置命名空间毫无关系——两处同名纯属命名约定。
    super("app:index:BucketFleet", name, {}, opts);

    // 关键：把库名 "app" 传给 Config，只读取 app: 前缀的键。
    const config = new pulumi.Config("app");
    const prefix = config.require("bucketPrefix");      // app:bucketPrefix
    const count = config.getNumber("bucketCount") ?? 1; // app:bucketCount

    const buckets: s3.Bucket[] = [];
    for (let i = 0; i < count; i++) {
      buckets.push(new s3.Bucket(\`\${name}-\${prefix}-\${i}\`, {
        tags: { component: "BucketFleet" },
      }, { provider: args.provider, parent: this }));
    }

    this.bucketNames = pulumi.all(buckets.map(b => b.bucket));
    this.registerOutputs({ bucketNames: this.bucketNames });
  }
}

const fleet = new BucketFleet("fleet", { provider: localAws });
export const fleetBucketNames = fleet.bucketNames;
TS

# 初始程序使用 base 变体。
cp variants/base.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true

docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true

# 启动 MiniStack 并等待健康检查通过，确保学员到达 step1 时模拟器已就绪。
echo "启动 MiniStack……"
docker compose up -d >/dev/null 2>&1 || true
for i in $(seq 1 60); do
  if curl -fs http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    echo "MiniStack 已就绪。"
    break
  fi
  sleep 2
done

touch /tmp/.setup-done
echo "[$(date +%Y-%m-%dT%H:%M:%S)] AWS / MiniStack config lab is ready in /root/workspace"
