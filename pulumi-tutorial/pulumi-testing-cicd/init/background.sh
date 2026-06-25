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

mkdir -p asserts
cat > asserts/unit.spec.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { strict as assert } from "node:assert";
import "mocha";

// 单元测试不会访问 MiniStack 或 AWS。这里的 mock runtime 会接住 Pulumi 程序注册资源时传入的输入，
// 并返回测试需要的假 provider 输出。
pulumi.runtime.setMocks({
	newResource(args: pulumi.runtime.MockResourceArgs) {
		return {
			id: `${args.name}_id`,
			state: {
				...args.inputs,
				// arn 通常由 AWS provider 计算。这里手工合成一个值，
				// 让测试无需创建真实 Bucket 也能读取它。
				arn: `arn:aws:s3:::${args.inputs.bucket ?? args.name}`,
			},
		};
	},
	call(args: pulumi.runtime.MockCallArgs) {
		return args.inputs;
	},
}, "pulumi-testing-cicd", "dev", false);

// 即使在单元测试里，资源属性仍然是 Output，所以断言前要先等待它 resolve。
function outputOf<T>(value: pulumi.Output<T>): Promise<T> {
	return new Promise((resolve) => value.apply(resolve));
}

describe("bucket contract", () => {
	let infra: typeof import("../index");

	before(async () => {
		// 一定要先 setMocks，再导入 Pulumi 程序。导入 index.ts 会立即创建资源对象，
		// 所以 mock runtime 必须提前准备好。
		infra = await import("../index");
	});

	it("allows cleanup in test environments", async () => {
		// forceDestroy 让短生命周期测试 Stack 更容易清理。
		assert.equal(await outputOf(infra.bucket.forceDestroy), true);
	});

	it("declares ownership tags", async () => {
		// 这是红灯测试：初始的 index.ts 还没有这两个标签。
		const tags = await outputOf(infra.bucket.tags);
		assert.equal(tags?.owner, "platform-team");
		assert.equal(tags?.managedBy, "pulumi");
	});
});
TS

npm install --no-audit --no-fund >/dev/null
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null
pulumi config set prefix testing >/dev/null

if ! command -v act >/dev/null 2>&1; then
	curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin >/dev/null
fi

service docker start >/dev/null 2>&1 || true

touch /tmp/.setup-done