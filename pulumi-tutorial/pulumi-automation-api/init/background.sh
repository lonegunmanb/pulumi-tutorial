#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-automation-api"
export SCENARIO_TITLE="Automation API：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done
mkdir -p /root/workspace

if [ ! -f /swapfile ]; then
	fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null || true
	chmod 600 /swapfile 2>/dev/null || true
	mkswap /swapfile >/dev/null 2>&1 || true
	swapon /swapfile >/dev/null 2>&1 || true
fi

bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

for line in 'export PULUMI_CONFIG_PASSPHRASE=""' 'export TS_NODE_TRANSPILE_ONLY=1' 'export NODE_OPTIONS=--max-old-space-size=512'; do
	grep -q "$line" /root/.bashrc 2>/dev/null || echo "$line" >> /root/.bashrc
done

apt-get install -y unzip >/dev/null 2>&1 || true
if ! command -v aws >/dev/null 2>&1; then
	if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null; then
		unzip -o -q /tmp/awscliv2.zip -d /tmp >/dev/null 2>&1 \
			&& /tmp/aws/install --update >/dev/null 2>&1
		rm -rf /tmp/awscliv2.zip /tmp/aws
	fi
	command -v aws >/dev/null 2>&1 || apt-get install -y awscli >/dev/null 2>&1 || true
fi

service docker start >/dev/null 2>&1 || true
if ! docker compose version >/dev/null 2>&1; then
	mkdir -p /usr/local/lib/docker/cli-plugins
	curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
		-o /usr/local/lib/docker/cli-plugins/docker-compose
	chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
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
		container_name: pulumi-automation-api-ministack
		ports:
			- "4566:4566"
		environment:
			MINISTACK_REGION: us-east-1
			MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cat > package.json <<'JSON'
{
	"name": "pulumi-automation-api-aws-lab",
	"version": "1.0.0",
	"private": true,
	"scripts": {
		"automation": "ts-node --transpile-only automation.ts",
		"server": "ts-node --transpile-only server.ts"
	},
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
name: pulumi-automation-api
runtime:
	name: nodejs
	options:
		nodeargs: "--max-old-space-size=512"
description: Automation API local program for an AWS artifact environment on MiniStack.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as s3 from "@pulumi/aws/s3";
import { Provider } from "@pulumi/aws/provider";

interface EnvironmentSettings {
	namePrefix: string;
	region: string;
	owner: string;
	dataClass: string;
	artifactName: string;
	artifactBody: string;
	tags: Record<string, string>;
}

const stack = pulumi.getStack();
const project = pulumi.getProject();
const config = new pulumi.Config();
const settings = config.requireObject<EnvironmentSettings>("settings");
const releaseToken = config.requireSecret("releaseToken");

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

const commonTags = {
	...settings.tags,
	owner: settings.owner,
	project,
	environment: stack,
	dataClass: settings.dataClass,
	managedBy: "pulumi",
};

const bucket = new s3.Bucket("artifact-bucket", {
	bucket: `${settings.namePrefix}-${stack}-artifacts`,
	forceDestroy: true,
	tags: commonTags,
}, { provider: localAws });

const artifact = new s3.BucketObject("artifact", {
	bucket: bucket.bucket,
	key: settings.artifactName,
	content: settings.artifactBody,
	contentType: "text/plain; charset=utf-8",
}, { provider: localAws });

export const environment = stack;
export const bucketName = bucket.bucket;
export const artifactKey = artifact.key;
export const artifactUrl = pulumi.interpolate`http://localhost:4566/${bucket.bucket}/${artifact.key}`;
export const owner = settings.owner;
export const tokenHint = releaseToken.apply((value) => `token length: ${value.length}`);
TS

cat > automation.ts <<'TS'
import * as automation from "@pulumi/pulumi/automation";

export type Action = "preview" | "up" | "refresh" | "destroy" | "outputs";

const projectName = "pulumi-automation-api";
const pluginVersion = "v7.0.0";

interface EnvironmentSettings {
	namePrefix: string;
	region: string;
	owner: string;
	dataClass: string;
	artifactName: string;
	artifactBody: string;
	tags: Record<string, string>;
}

const profiles: Record<string, EnvironmentSettings> = {
	dev: {
		namePrefix: "autoapi-dev",
		region: "us-east-1",
		owner: "platform-dev",
		dataClass: "test",
		artifactName: "dev/release.txt",
		artifactBody: "created from Automation API for dev",
		tags: {
			costCenter: "lab-dev",
			service: "artifact-service",
		},
	},
	review: {
		namePrefix: "autoapi-review",
		region: "us-east-1",
		owner: "platform-review",
		dataClass: "temporary",
		artifactName: "review/release.txt",
		artifactBody: "created from the HTTP wrapper",
		tags: {
			costCenter: "lab-review",
			service: "artifact-service",
		},
	},
};

function safeStackPart(stackName: string): string {
	return stackName.toLowerCase().replace(/[^a-z0-9-]/g, "-").slice(0, 30) || "env";
}

function profileFor(stackName: string): EnvironmentSettings {
	if (profiles[stackName]) {
		return profiles[stackName];
	}

	const safe = safeStackPart(stackName);
	return {
		namePrefix: `autoapi-${safe}`,
		region: "us-east-1",
		owner: "platform-self-service",
		dataClass: "temporary",
		artifactName: `${safe}/release.txt`,
		artifactBody: `created for ${safe}`,
		tags: {
			costCenter: "lab-dynamic",
			service: "artifact-service",
		},
	};
}

function envVars(): Record<string, string> {
	return {
		PULUMI_CONFIG_PASSPHRASE: process.env.PULUMI_CONFIG_PASSPHRASE ?? "",
		TS_NODE_TRANSPILE_ONLY: "1",
		NODE_OPTIONS: process.env.NODE_OPTIONS ?? "--max-old-space-size=512",
		AWS_ACCESS_KEY_ID: "test",
		AWS_SECRET_ACCESS_KEY: "test",
		AWS_DEFAULT_REGION: "us-east-1",
	};
}

function logEvent(event: any): void {
	if (event.resourcePreEvent) {
		const metadata = event.resourcePreEvent.metadata;
		console.log(`[event] ${metadata.op} ${metadata.type} ${metadata.name}`);
	}
	if (event.diagnosticEvent?.severity === "error") {
		console.error(`[diagnostic] ${event.diagnosticEvent.message}`);
	}
}

function operationOptions() {
	return {
		onOutput: (line: string) => console.log(line),
		onEvent: logEvent,
	};
}

function simplifyOutputs(outputs: automation.OutputMap | undefined): Record<string, unknown> {
	const result: Record<string, unknown> = {};
	for (const [key, value] of Object.entries(outputs ?? {})) {
		result[key] = value.secret ? "[secret]" : value.value;
	}
	return result;
}

async function selectStack(stackName: string): Promise<automation.Stack> {
	const stack = await automation.LocalWorkspace.createOrSelectStack(
		{ stackName, workDir: process.cwd() },
		{ envVars: envVars() },
	);

	await stack.workspace.installPlugin("aws", pluginVersion);
	await configureStack(stack, stackName);
	return stack;
}

async function configureStack(stack: automation.Stack, stackName: string): Promise<void> {
	const settings = profileFor(stackName);
	await stack.setConfig("aws:region", { value: settings.region });
	await stack.setConfig(`${projectName}:settings`, { value: JSON.stringify(settings) });
	await stack.setConfig(`${projectName}:releaseToken`, {
		value: `token-${safeStackPart(stackName)}-local-only`,
		secret: true,
	});
}

export async function run(action: Action, stackName = "dev"): Promise<Record<string, unknown>> {
	const stack = await selectStack(stackName);
	const opts = operationOptions();

	if (action === "preview") {
		const result: any = await stack.preview(opts);
		return { action, stackName, changeSummary: result.changeSummary };
	}

	if (action === "up") {
		const result: any = await stack.up(opts);
		return { action, stackName, summary: result.summary, outputs: simplifyOutputs(result.outputs) };
	}

	if (action === "refresh") {
		const result: any = await stack.refresh(opts);
		return { action, stackName, summary: result.summary };
	}

	if (action === "destroy") {
		const result: any = await stack.destroy(opts);
		return { action, stackName, summary: result.summary };
	}

	if (action === "outputs") {
		return { action, stackName, outputs: simplifyOutputs(await stack.outputs()) };
	}

	throw new Error(`Unsupported action: ${action}`);
}

async function main(): Promise<void> {
	const action = (process.argv[2] ?? "preview") as Action;
	const stackName = process.argv[3] ?? "dev";
	const result = await run(action, stackName);
	console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
	main().catch((error) => {
		console.error(error instanceof Error ? error.message : error);
		process.exit(1);
	});
}
TS

cat > server.ts <<'TS'
import { createServer, ServerResponse } from "http";
import { Action, run } from "./automation";

function send(res: ServerResponse, statusCode: number, body: unknown): void {
	res.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
	res.end(JSON.stringify(body, null, 2));
}

function route(method: string, pathname: string): { action: Action; stackName: string } | undefined {
	const match = pathname.match(/^\/environments\/([A-Za-z0-9._-]+)(?:\/(preview|refresh|outputs))?$/);
	if (!match) {
		return undefined;
	}

	const stackName = match[1];
	const suffix = match[2];

	if (method === "POST" && suffix === "preview") return { action: "preview", stackName };
	if (method === "POST" && suffix === "refresh") return { action: "refresh", stackName };
	if (method === "POST" && !suffix) return { action: "up", stackName };
	if (method === "GET" && suffix === "outputs") return { action: "outputs", stackName };
	if (method === "DELETE" && !suffix) return { action: "destroy", stackName };
	return undefined;
}

const server = createServer(async (req, res) => {
	const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);
	const request = route(req.method ?? "GET", url.pathname);

	if (!request) {
		send(res, 404, { error: "not found" });
		return;
	}

	try {
		const result = await run(request.action, request.stackName);
		send(res, 200, result);
	} catch (error) {
		send(res, 500, { error: error instanceof Error ? error.message : String(error) });
	}
});

server.listen(3000, "0.0.0.0", () => {
	console.log("Automation API wrapper is listening on http://localhost:3000");
});
TS

npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true

pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
pulumi config set aws:region us-east-1 >/dev/null 2>&1 || true
pulumi config set pulumi-automation-api:settings '{"namePrefix":"autoapi-dev","region":"us-east-1","owner":"platform-dev","dataClass":"test","artifactName":"dev/release.txt","artifactBody":"created from CLI baseline","tags":{"costCenter":"lab-dev","service":"artifact-service"}}' >/dev/null 2>&1 || true
pulumi config set pulumi-automation-api:releaseToken cli-token-local-only --secret >/dev/null 2>&1 || true

git init >/dev/null 2>&1 || true
git config user.email pulumi-lab@example.com >/dev/null 2>&1 || true
git config user.name "Pulumi Lab" >/dev/null 2>&1 || true
git add Pulumi.yaml Pulumi.dev.yaml index.ts automation.ts server.ts package.json package-lock.json tsconfig.json docker-compose.yml >/dev/null 2>&1 || true
git commit -m "Initial Automation API AWS lab" >/dev/null 2>&1 || true

docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true
docker compose up -d >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
	curl -fs http://localhost:4566/_ministack/health >/dev/null 2>&1 && break
	sleep 2
done

touch /tmp/.setup-done
echo "AWS / MiniStack Automation API lab is ready in /root/workspace"