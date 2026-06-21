#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-assets-archives"
export SCENARIO_TITLE="Assets 与 Archives：AWS / MiniStack 版"
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

apt-get install -y zip unzip >/dev/null 2>&1 || true

# Killercoda 已预装 Docker，这里只确保守护进程在运行。
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

# AWS CLI 供 awslocal 读取 S3 对象和 invoke Lambda。
if ! command -v aws >/dev/null 2>&1; then
  if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null; then
    unzip -o -q /tmp/awscliv2.zip -d /tmp >/dev/null 2>&1 \
      && /tmp/aws/install --update >/dev/null 2>&1
    rm -rf /tmp/awscliv2.zip /tmp/aws
  fi
  command -v aws >/dev/null 2>&1 || apt-get install -y awscli >/dev/null 2>&1 || true
fi

cat > /usr/local/bin/awslocal <<'WRAPPER'
#!/usr/bin/env bash
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
exec aws --endpoint-url=http://localhost:4566 --region "$AWS_DEFAULT_REGION" "$@"
WRAPPER
chmod +x /usr/local/bin/awslocal

mkdir -p /root/workspace/assets /root/workspace/site /root/workspace/lambda-file /root/workspace/lambda-remote /root/workspace/payload /root/workspace/dist /root/workspace/variants
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-assets-archives-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
  "name": "pulumi-assets-archives-lab",
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
name: pulumi-assets-archives
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Explore Pulumi Assets and Archives with AWS resources against MiniStack.
YAML

cat > assets/file-note.txt <<'TEXT'
This object was uploaded from a FileAsset.
TEXT

cat > assets/remote-note.txt <<'TEXT'
This object was loaded through a file:// RemoteAsset.
TEXT

cat > site/index.html <<'HTML'
<!doctype html>
<html>
  <body>Packaged from a nested FileArchive.</body>
</html>
HTML

cat > payload/message.txt <<'TEXT'
message from FileAsset inside AssetArchive
TEXT

cat > lambda-file/index.js <<'JS'
exports.handler = async () => {
  return {
    packageKind: "FileArchive",
    message: "handler loaded from a local directory",
  };
};
JS

cat > lambda-remote/index.js <<'JS'
exports.handler = async () => {
  return {
    packageKind: "RemoteArchive",
    message: "handler loaded from a file URI zip archive",
  };
};
JS

(cd lambda-remote && zip -qr ../dist/remote-function.zip .) || true

cat > common.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as s3 from "@pulumi/aws/s3";
import * as iam from "@pulumi/aws/iam";
import { Provider } from "@pulumi/aws/provider";

export const localAws = new Provider("ministack", {
  region: "us-east-1",
  accessKey: "test",
  secretKey: "test",
  skipCredentialsValidation: true,
  skipMetadataApiCheck: true,
  skipRequestingAccountId: true,
  s3UsePathStyle: true,
  endpoints: [{
    s3: "http://localhost:4566",
    sts: "http://localhost:4566",
    iam: "http://localhost:4566",
    lambda: "http://localhost:4566",
    cloudwatchlogs: "http://localhost:4566",
  }],
});

export function createAssetBucket() {
  const bucket = new s3.Bucket("asset-demo-bucket", {
    forceDestroy: true,
    tags: { topic: "assets-archives" },
  }, { provider: localAws });

  const stringObject = new s3.BucketObject("string-asset-object", {
    bucket: bucket.id,
    key: "notes/string.txt",
    source: new pulumi.asset.StringAsset("This object was created from a StringAsset.\n"),
    contentType: "text/plain",
  }, { provider: localAws });

  const fileObject = new s3.BucketObject("file-asset-object", {
    bucket: bucket.id,
    key: "notes/from-file.txt",
    source: new pulumi.asset.FileAsset("./assets/file-note.txt"),
    contentType: "text/plain",
  }, { provider: localAws });

  const remoteObject = new s3.BucketObject("remote-asset-object", {
    bucket: bucket.id,
    key: "notes/from-file-uri.txt",
    source: new pulumi.asset.RemoteAsset("file:///root/workspace/assets/remote-note.txt"),
    contentType: "text/plain",
  }, { provider: localAws });

  return { bucket, stringObject, fileObject, remoteObject };
}

export function createLambdaRole() {
  const role = new iam.Role("asset-lambda-role", {
    assumeRolePolicy: JSON.stringify({
      Version: "2012-10-17",
      Statement: [{
        Action: "sts:AssumeRole",
        Effect: "Allow",
        Principal: { Service: "lambda.amazonaws.com" },
      }],
    }),
  }, { provider: localAws });

  new iam.RolePolicy("asset-lambda-logs", {
    role: role.id,
    policy: JSON.stringify({
      Version: "2012-10-17",
      Statement: [{
        Effect: "Allow",
        Action: ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource: "*",
      }],
    }),
  }, { provider: localAws });

  return role;
}
TS

cat > variants/base.ts <<'TS'
import { createAssetBucket } from "./common";

const assets = createAssetBucket();

export const bucketName = assets.bucket.bucket;
export const stringObjectKey = assets.stringObject.key;
export const fileObjectKey = assets.fileObject.key;
export const remoteObjectKey = assets.remoteObject.key;
TS

cat > variants/step2-file-archive.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as lambda from "@pulumi/aws/lambda";
import { createAssetBucket, createLambdaRole, localAws } from "./common";

const assets = createAssetBucket();
const role = createLambdaRole();

const fn = new lambda.Function("asset-packager", {
  role: role.arn,
  runtime: "nodejs20.x",
  handler: "index.handler",
  code: new pulumi.asset.FileArchive("./lambda-file"),
  timeout: 10,
}, { provider: localAws });

export const bucketName = assets.bucket.bucket;
export const functionName = fn.name;
export const packageKind = "FileArchive";
TS

cat > variants/step3-asset-archive.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as lambda from "@pulumi/aws/lambda";
import { createAssetBucket, createLambdaRole, localAws } from "./common";

const assets = createAssetBucket();
const role = createLambdaRole();

const code = new pulumi.asset.AssetArchive({
  "index.js": new pulumi.asset.StringAsset(`
const fs = require("fs");
const path = require("path");

exports.handler = async () => {
  const message = fs.readFileSync(path.join(__dirname, "message.txt"), "utf8").trim();
  return {
    packageKind: "AssetArchive",
    message,
    hasPublicFolder: fs.existsSync(path.join(__dirname, "public", "index.html")),
  };
};
`),
  "message.txt": new pulumi.asset.FileAsset("./payload/message.txt"),
  "public": new pulumi.asset.FileArchive("./site"),
});

const fn = new lambda.Function("asset-packager", {
  role: role.arn,
  runtime: "nodejs20.x",
  handler: "index.handler",
  code,
  timeout: 10,
}, { provider: localAws });

export const bucketName = assets.bucket.bucket;
export const functionName = fn.name;
export const packageKind = "AssetArchive";
TS

cat > variants/step4-remote-archive.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as lambda from "@pulumi/aws/lambda";
import { createAssetBucket, createLambdaRole, localAws } from "./common";

const assets = createAssetBucket();
const role = createLambdaRole();

const fn = new lambda.Function("asset-packager", {
  role: role.arn,
  runtime: "nodejs20.x",
  handler: "index.handler",
  code: new pulumi.asset.RemoteArchive("file:///root/workspace/dist/remote-function.zip"),
  timeout: 10,
}, { provider: localAws });

export const bucketName = assets.bucket.bucket;
export const functionName = fn.name;
export const packageKind = "RemoteArchive";
TS

cp variants/base.ts index.ts

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true

docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true
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
  echo "Assets and Archives lab is ready in /root/workspace (MiniStack healthy)"
else
  echo "MiniStack 健康检查未通过，未创建 /tmp/.setup-done。可执行 'docker compose ps' 与 'docker compose logs ministack' 排查。"
fi