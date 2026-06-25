#!/usr/bin/env bash
set -euo pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-testing-cicd"
export SCENARIO_TITLE="测试驱动开发与 CI/CD：AWS / MiniStack 版"
export PULUMI_CONFIG_PASSPHRASE=""
export SKIP_SAMPLE_PROJECT=1
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done
bash /root/setup-common.sh || true

export PATH="$HOME/.pulumi/bin:$PATH"
for line in 'export PULUMI_CONFIG_PASSPHRASE=""' 'export TS_NODE_TRANSPILE_ONLY=1' 'export NODE_OPTIONS=--max-old-space-size=512'; do
	grep -q "$line" /root/.bashrc 2>/dev/null || echo "$line" >> /root/.bashrc
done

apt-get install -y curl jq unzip >/dev/null 2>&1 || true
service docker start >/dev/null 2>&1 || true
if ! docker compose version >/dev/null 2>&1; then
	mkdir -p /usr/local/lib/docker/cli-plugins
	curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
		-o /usr/local/lib/docker/cli-plugins/docker-compose
	chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

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

cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-testing-cicd-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

docker compose up -d >/dev/null 2>&1 || true
for attempt in $(seq 1 60); do
	if curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
		break
	fi
	if [ "$attempt" = "60" ]; then
		docker compose logs || true
		exit 1
	fi
	sleep 2
done

cat > package.json <<'JSON'
{
  "name": "pulumi-testing-cicd-aws-lab",
	"version": "1.0.0",
	"private": true,
	"scripts": {
		"test": "npm run test:unit",
		"test:unit": "mocha -r ts-node/register test/unit.spec.ts",
		"test:integration": "mocha -r ts-node/register test/integration.spec.ts",
		"test:all": "npm run test:unit && npm run test:integration",
		"preview:ci": "pulumi stack select dev && pulumi preview --non-interactive"
	},
	"dependencies": {
		"@pulumi/aws": "^7.0.0",
		"@pulumi/pulumi": "^3.0.0"
	},
	"devDependencies": {
		"@types/mocha": "^10.0.0",
		"@types/node": "^20.0.0",
		"mocha": "^10.0.0",
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
	}
}
JSON

cat > Pulumi.yaml <<'YAML'
name: pulumi-testing-cicd
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: TDD and CI/CD lab for AWS resources against MiniStack.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as s3 from "@pulumi/aws/s3";
import { Provider } from "@pulumi/aws/provider";

const config = new pulumi.Config();
const prefix = config.get("prefix") ?? "testing";

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

export const bucket = new s3.Bucket("artifact-bucket", {
	bucket: `${prefix}-artifact-bucket`,
	forceDestroy: true,
	tags: {
		environment: "dev",
	},
}, { provider: localAws });

export const bucketName = bucket.bucket;
export const bucketArn = bucket.arn;
TS

npm install --no-audit --no-fund >/dev/null
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null
pulumi config set prefix testing >/dev/null

if ! command -v act >/dev/null 2>&1; then
	curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin >/dev/null
fi

service docker start >/dev/null 2>&1 || true

touch /tmp/.setup-done