#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-functions"
export SCENARIO_TITLE="Pulumi Functions：四类函数（AWS / MiniStack）"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

rm -f /tmp/.setup-done
mkdir -p /root/workspace/variants

# 安装 Pulumi、Node.js 与共享工具（尽力而为，单步失败不影响后续）。
bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi

# Killercoda 已预装 Docker，这里只确保守护进程在运行。
service docker start >/dev/null 2>&1 || true

# 安装 AWS CLI v2（供 awslocal 使用），失败不致命。
if ! command -v aws >/dev/null 2>&1; then
  apt-get install -y unzip >/dev/null 2>&1 || true
  if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null; then
    unzip -o -q /tmp/awscliv2.zip -d /tmp >/dev/null 2>&1 \
      && /tmp/aws/install --update >/dev/null 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
  fi
  command -v aws >/dev/null 2>&1 || apt-get install -y awscli >/dev/null 2>&1 || true
fi

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

# awslocal：把 AWS CLI 指向本地 MiniStack（localhost:4566）。
cat > /usr/local/bin/awslocal <<'WRAPPER'
#!/usr/bin/env bash
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
exec aws --endpoint-url=http://localhost:4566 --region "$AWS_DEFAULT_REGION" "$@"
WRAPPER
chmod +x /usr/local/bin/awslocal

cd /root/workspace

# MiniStack：仅挂载 Docker socket 让 EKS 能拉起真实的 k3s 容器。
# Node.js Lambda 走默认的 local 执行器（在 MiniStack 容器内以 node 子进程运行），无需 DinD。
cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-functions-ministack
    privileged: true
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
    volumes:
      # 挂载 Docker socket 仅用于 EKS——CreateCluster 会拉起一个真实的 k3s 容器。
      # Node.js Lambda 默认以 local（node 子进程）模式在 MiniStack 容器内执行，无需 DinD。
      - /var/run/docker.sock:/var/run/docker.sock
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-functions-lab",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@pulumi/aws": "^6.66.0",
    "@pulumi/eks": "^3.0.0",
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
name: pulumi-functions
runtime: nodejs
description: Explore Pulumi's three function types plus function serialization on MiniStack.
YAML

# ---------- step1：provider functions（direct / output form）----------
cat > variants/step1.ts <<'TS'
import * as aws from "@pulumi/aws";

// output form：接受 Input、返回 Output，参与依赖图。
// getCallerIdentity 会调用 MiniStack 的 STS API。
const idOut = aws.getCallerIdentityOutput({});
export const accountIdOutputForm = idOut.accountId;
export const callerArn = idOut.arn;

// direct form：返回 Promise，await 得到普通值（适合"要不要建资源"的分支判断）。
export const accountIdDirectForm = aws.getCallerIdentity({}).then((r) => r.accountId);
TS

# ---------- step2：get function（引用未托管资源）----------
cat > variants/step2.ts <<'TS'
import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
// 这个 ARN 指向一个用 CLI 预先建好的 SNS Topic——它不归 Pulumi 管理。
const topicArn = config.require("preexistingTopicArn");

// get：把这个未托管的 Topic 读进来。Pulumi 永远不会修改/删除它。
const topic = aws.sns.Topic.get("preexisting", topicArn);

// 用读到的 Topic 的属性，创建由 Pulumi 管理的资源：一个 SQS 队列 + 一个订阅。
const queue = new aws.sqs.Queue("fn-demo-queue", {});
new aws.sns.TopicSubscription("fn-demo-sub", {
  topic: topic.arn, // 这里引用的是"未托管资源"的属性
  protocol: "sqs",
  endpoint: queue.arn,
});

export const unmanagedTopicArn = topic.arn;
export const unmanagedTopicName = topic.name;
export const managedQueueUrl = queue.id;
TS

# ---------- step3：function serialization（闭包 -> Lambda）----------
cat > variants/step3.ts <<'TS'
import * as aws from "@pulumi/aws";

// 下面两个变量定义在闭包外部——函数序列化时会被一并捕获并打包进 Lambda。
const greetingPrefix = "Hello from a serialized closure";
const builtAt = new Date().toISOString();

// CallbackFunction 会替你序列化回调、创建 Role/Policy、打包代码并建出 Lambda。
const greeter = new aws.lambda.CallbackFunction("fn-greeter", {
  runtime: aws.lambda.Runtime.NodeJS20dX,
  callback: async (event: { name?: string }) => {
    // 这段代码会在 MiniStack 的 Node.js 运行时里执行。
    const who = event && event.name ? event.name : "world";
    return { message: `${greetingPrefix}: ${who}`, builtAt };
  },
});

export const greeterFunctionName = greeter.name;
TS

# ---------- step4：resource method（EKS getKubeconfig）----------
cat > variants/step4.ts <<'TS'
import * as aws from "@pulumi/aws";
import * as eks from "@pulumi/eks";

// 一个最小 VPC + 两个子网，显式交给 eks 用，避免它去寻找默认 VPC。
const vpc = new aws.ec2.Vpc("fn-eks-vpc", { cidrBlock: "10.0.0.0/16" });
const subnetA = new aws.ec2.Subnet("fn-eks-subnet-a", {
  vpcId: vpc.id,
  cidrBlock: "10.0.1.0/24",
  availabilityZone: "us-east-1a",
});
const subnetB = new aws.ec2.Subnet("fn-eks-subnet-b", {
  vpcId: vpc.id,
  cidrBlock: "10.0.2.0/24",
  availabilityZone: "us-east-1b",
});

// 由 Pulumi 管理的 EKS 集群（MiniStack 会拉起一个真实的 k3s 容器来模拟）。
const cluster = new eks.Cluster("fn-eks", {
  name: "pulumi-functions-eks",
  vpcId: vpc.id,
  publicSubnetIds: [subnetA.id, subnetB.id],
  skipDefaultNodeGroup: true,   // 不建节点组，保持轻量
  createOidcProvider: false,
  authenticationMode: "API",    // 用 EKS Access Entry，免去往集群里写 aws-auth
  // MiniStack 未实现 aws:eks/getAddonVersion，关掉这几个托管插件，避免 invoke 报错。
  useDefaultVpcCni: true,                  // 不把 vpc-cni 作为独立 addon 管理
  kubeProxyAddonOptions: { enabled: false },
  corednsAddonOptions: { enabled: false },
});

// resource method：从这个"已托管"的集群上取派生值——kubeconfig。
export const kubeconfig = cluster.getKubeconfig();
TS

# 起步用一个空程序，避免学员在进入第一个步骤前误触发资源创建。
cat > index.ts <<'TS'
// 各步骤会把 variants/ 下对应的程序复制到这里。
export const ready = "pulumi-functions lab";
TS

npm install --no-audit --no-fund >/dev/null 2>&1 || true

pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true

# 配置 default AWS provider，把所有调用指向 MiniStack（含 @pulumi/eks 内部资源）。
pulumi config set aws:region us-east-1 >/dev/null 2>&1 || true
pulumi config set aws:accessKey test >/dev/null 2>&1 || true
pulumi config set aws:secretKey test >/dev/null 2>&1 || true
pulumi config set aws:skipCredentialsValidation true >/dev/null 2>&1 || true
pulumi config set aws:skipMetadataApiCheck true >/dev/null 2>&1 || true
pulumi config set aws:skipRequestingAccountId true >/dev/null 2>&1 || true
pulumi config set aws:s3UsePathStyle true >/dev/null 2>&1 || true
for svc in sts iam lambda sns sqs ec2 eks cloudwatchlogs cloudwatch s3; do
  pulumi config set --path "aws:endpoints[0].$svc" http://localhost:4566 >/dev/null 2>&1 || true
done

# 预拉镜像，缩短各步骤等待：MiniStack、k3s（EKS）。
docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true
docker pull rancher/k3s:latest >/dev/null 2>&1 || true

# 启动 MiniStack 并等它健康检查通过——只有通过了才创建 /tmp/.setup-done，
# 让 foreground.sh 据此提示学员开始实验。
docker compose up -d >/dev/null 2>&1 || true
ministack_ready=0
for _ in $(seq 1 120); do
  if curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    ministack_ready=1
    break
  fi
  sleep 2
done

if [ "$ministack_ready" = "1" ]; then
  touch /tmp/.setup-done
  echo "Functions lab is ready in /root/workspace (MiniStack healthy)"
else
  echo "MiniStack 健康检查未通过，未创建 /tmp/.setup-done。可执行 'docker compose ps' 与 'docker compose logs ministack' 排查。"
fi
