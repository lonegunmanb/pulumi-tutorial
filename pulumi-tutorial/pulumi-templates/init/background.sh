#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-templates"
export SCENARIO_TITLE="Pulumi Templates"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512

rm -f /tmp/.setup-done

bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

cat > /root/.pulumi-templates-env.sh <<'SH'
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
SH

if ! grep -q '.pulumi-templates-env.sh' /root/.bashrc 2>/dev/null; then
  echo 'source /root/.pulumi-templates-env.sh' >> /root/.bashrc
fi

mkdir -p /root/workspace/templates-lab/service-template
cd /root/workspace/templates-lab/service-template

cat > Pulumi.yaml <<'YAML'
name: ${PROJECT}
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: ${DESCRIPTION}
template:
  displayName: Service Infrastructure Template
  description: A local TypeScript template for a service infrastructure project.
  quickstart: Run npm install, then pulumi preview, then pulumi up.
  important: false
  config:
    serviceName:
      description: The service name used in resource naming and tags.
      default: demo-service
    owner:
      description: The team responsible for this stack.
      default: platform-team
    apiToken:
      description: Example sensitive token stored as a Pulumi secret.
      secret: true
  metadata:
    category: service
    cloud: local
YAML

cat > package.json <<'JSON'
{
  "name": "${PROJECT}",
  "version": "1.0.0",
  "private": true,
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

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "ts-node": {
    "transpileOnly": true
  }
}
JSON

cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as random from "@pulumi/random";

const config = new pulumi.Config();
const serviceName = config.require("serviceName");
const owner = config.get("owner") ?? "platform-team";
const apiToken = config.requireSecret("apiToken");

const suffix = new random.RandomPet("service-suffix", {
  prefix: serviceName,
  length: 2,
});

export const generatedProject = "${PROJECT}";
export const projectDescription = "${DESCRIPTION}";
export const service = serviceName;
export const ownerName = owner;
export const serviceResourceName = suffix.id;
export const tokenPreview = apiToken.apply(token => `${token.slice(0, 3)}***`);
TS

cat > README.md <<'MD'
# ${PROJECT}

${DESCRIPTION}

## What this template creates

This project demonstrates a local Pulumi template with config prompts, a secret value, and a small random resource.

## Commands

```bash
npm install
pulumi preview
pulumi up
```

The template quickstart repeats the same first steps after `pulumi new` completes.
MD

pulumi login --local >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Pulumi Templates lab is ready in /root/workspace/templates-lab"