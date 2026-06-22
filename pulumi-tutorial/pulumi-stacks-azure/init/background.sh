#!/usr/bin/env bash
set -euo pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-stacks-azure"
export SCENARIO_TITLE="Stack 详解（Azure / miniblue）"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

rm -f /tmp/.setup-done

bash /root/setup-common.sh
export PATH="$HOME/.pulumi/bin:$PATH"

apt-get install -y python3-pip python3-venv jq >/dev/null
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/workspace/azure-stacks
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-6d934ae
    container_name: pulumi-stacks-detail-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cd /root/workspace/azure-stacks

cat > Pulumi.yaml <<'YAML'
name: stacks-azure-lab
runtime:
  name: python
  options:
    virtualenv: venv
description: Learn Pulumi stacks with miniblue Azure-style resources.
YAML

cat > requirements.txt <<'REQ'
pulumi>=3.0.0
requests>=2.31.0
REQ

cat > __main__.py <<'PY'
import pulumi
import requests
from pulumi.dynamic import CreateResult, Resource, ResourceProvider

MINIBLUE_URL = "http://localhost:4566"
SUBSCRIPTION = "00000000-0000-0000-0000-000000000000"


class ResourceGroupProvider(ResourceProvider):
    def create(self, props):
        name = props["name"]
        response = requests.put(
            f"{MINIBLUE_URL}/subscriptions/{SUBSCRIPTION}/resourcegroups/{name}",
            json={"location": props["location"], "tags": props["tags"]},
            timeout=10,
        )
        response.raise_for_status()
        return CreateResult(id_=name, outs=dict(props))

    def delete(self, id, props):
        requests.delete(
            f"{MINIBLUE_URL}/subscriptions/{SUBSCRIPTION}/resourcegroups/{id}",
            timeout=10,
        )


class ResourceGroup(Resource):
    def __init__(self, resource_name, name, location, tags, opts=None):
        super().__init__(
            ResourceGroupProvider(),
            resource_name,
            {"name": name, "location": location, "tags": tags},
            opts,
        )


class KeyVaultSecretProvider(ResourceProvider):
    def create(self, props):
        response = requests.put(
            f"{MINIBLUE_URL}/keyvault/{props['vault']}/secrets/{props['secret_name']}",
            json={"value": props["value"]},
            timeout=10,
        )
        response.raise_for_status()
        return CreateResult(id_=f"{props['vault']}/{props['secret_name']}", outs=dict(props))

    def delete(self, id, props):
        requests.delete(
            f"{MINIBLUE_URL}/keyvault/{props['vault']}/secrets/{props['secret_name']}",
            timeout=10,
        )


class KeyVaultSecret(Resource):
    def __init__(self, resource_name, vault, secret_name, value, opts=None):
        super().__init__(
            KeyVaultSecretProvider(),
            resource_name,
            {"vault": vault, "secret_name": secret_name, "value": value},
            opts,
        )


stack = pulumi.get_stack()
project = pulumi.get_project()
config = pulumi.Config()

name_prefix = config.require("namePrefix")
owner = config.require("owner")
tier = config.require("tier")
admin_password = config.require_secret("adminPassword")

resource_group_name = f"{name_prefix}-{stack}-rg"
key_vault_name = f"{name_prefix}-{stack}-kv"
secret_name = "admin-password"

resource_group = ResourceGroup(
    "workload-rg",
    name=resource_group_name,
    location="eastus",
    tags={"environment": stack, "owner": owner, "tier": tier, "managedBy": "pulumi"},
)

secret = KeyVaultSecret(
    "admin-password",
    vault=key_vault_name,
    secret_name=secret_name,
    value=admin_password,
    opts=pulumi.ResourceOptions(depends_on=[resource_group]),
)

readme = pulumi.Output.concat(
    "# Stack ", stack, "\n\n",
    "This stack belongs to project `", project, "` and owns resource group `", resource_group_name, "`.\n",
)

pulumi.export("project", project)
pulumi.export("stack", stack)
pulumi.export("qualified_stack", pulumi.Output.concat("organization/", project, "/", stack))
pulumi.export("resource_group", resource_group_name)
pulumi.export("key_vault", key_vault_name)
pulumi.export("secret_name", secret_name)
pulumi.export("handoff_card", pulumi.Output.concat("Stack ", stack, " owns ", resource_group_name))
pulumi.export("adminPasswordPreview", admin_password)
pulumi.export("readme", readme)
PY

python3 -m venv venv >/dev/null
venv/bin/pip install --upgrade pip >/dev/null
venv/bin/pip install -r requirements.txt >/dev/null

pulumi login --local >/dev/null
docker pull ghcr.io/lonegunmanb/miniblue:sha-6d934ae >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Stack Azure lab is ready in /root/workspace/azure-stacks"