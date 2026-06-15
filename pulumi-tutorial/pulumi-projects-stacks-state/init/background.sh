#!/usr/bin/env bash
set -euo pipefail
export SCENARIO_ID="pulumi-projects-stacks-state"
export SCENARIO_TITLE="Projects、Stacks 与 State（AWS / MiniStack）"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

bash /root/setup-common.sh
export PATH="$HOME/.pulumi/bin:$PATH"

service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
	mkdir -p /usr/local/lib/docker/cli-plugins
	curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
		-o /usr/local/lib/docker/cli-plugins/docker-compose
	chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/workspace/aws-infra /root/workspace/aws-consumer
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
	ministack:
		image: ministackorg/ministack:latest
		container_name: pulumi-stacks-ministack
		ports:
			- "4566:4566"
		environment:
			MINISTACK_REGION: us-east-1
			MINISTACK_ACCOUNT_ID: "000000000000"
YAML

cd /root/workspace/aws-infra

cat > package.json <<'JSON'
{
	"name": "projects-stacks-aws-infra",
	"version": "1.0.0",
	"private": true,
	"type": "module",
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

cat > Pulumi.yaml <<'YAML'
name: projects-stacks-aws-infra
runtime:
	name: nodejs
description: Demonstrate Pulumi projects, stacks, config, secrets, outputs and local state with MiniStack.
YAML

cat > index.ts <<'TS'
import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

const stack = pulumi.getStack();
const config = new pulumi.Config();

const bucketBase = config.require("bucketBase");
const owner = config.require("owner");
const serviceToken = config.requireSecret("serviceToken");

const localAws = new aws.Provider("ministack", {
	region: "us-east-1",
	accessKey: "test",
	secretKey: "test",
	skipCredentialsValidation: true,
	skipMetadataApiCheck: true,
	skipRequestingAccountId: true,
	s3UsePathStyle: true,
	endpoints: [
		{
			s3: "http://localhost:4566",
			sts: "http://localhost:4566",
		},
	],
});

const assetsBucket = new aws.s3.Bucket("assets", {
	bucket: `${bucketBase}-${stack}`,
	forceDestroy: true,
	tags: {
		environment: stack,
		owner,
		managedBy: "pulumi",
	},
}, { provider: localAws });

export const environment = stack;
export const bucketName = assetsBucket.bucket;
export const ownerName = owner;
export const serviceTokenPreview = serviceToken;
export const handoffCard = pulumi.interpolate`Stack ${stack} owns S3 bucket ${assetsBucket.bucket}`;
TS

npm install --no-audit --no-fund >/dev/null

cd /root/workspace/aws-consumer

cat > package.json <<'JSON'
{
	"name": "projects-stacks-aws-consumer",
	"version": "1.0.0",
	"private": true,
	"type": "module",
	"dependencies": {
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
name: projects-stacks-aws-consumer
runtime:
	name: nodejs
description: Consume outputs from the AWS infra project through StackReference.
YAML

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";

const stack = pulumi.getStack();
const infra = new pulumi.StackReference(`organization/projects-stacks-aws-infra/${stack}`);

export const sourceEnvironment = infra.requireOutput("environment");
export const sourceBucket = infra.requireOutput("bucketName");
export const sourceHandoffCard = infra.requireOutput("handoffCard");
export const referencedSecret = infra.requireOutput("serviceTokenPreview");
TS

npm install --no-audit --no-fund >/dev/null

pulumi login --local >/dev/null
docker pull ministackorg/ministack:latest >/dev/null 2>&1 || true

echo "AWS / MiniStack projects-stacks-state lab is ready in /root/workspace"