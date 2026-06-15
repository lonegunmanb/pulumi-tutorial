#!/usr/bin/env bash
set -euo pipefail

export SCENARIO_ID="pulumi-projects-stacks-state-azure"
export SCENARIO_TITLE="Projects、Stacks 与 State（Azure / miniblue）"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

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

mkdir -p /root/workspace/azure-infra /root/workspace/azure-consumer
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-11ef0e8
    container_name: pulumi-stacks-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cd /root/workspace/azure-infra

cat > Pulumi.yaml <<'YAML'
name: projects-stacks-azure-infra
runtime:
  name: python
  options:
    virtualenv: venv
description: Demonstrate Pulumi projects, stacks, config, secrets, outputs and local state with miniblue.
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
config = pulumi.Config()

name_prefix = config.require("namePrefix")
owner = config.require("owner")
admin_password = config.require_secret("adminPassword")

resource_group_name = f"{name_prefix}-{stack}-rg"
key_vault_name = f"{name_prefix}-{stack}-kv"
secret_name = "admin-password"

resource_group = ResourceGroup(
    "workload-rg",
    name=resource_group_name,
    location="eastus",
    tags={"environment": stack, "owner": owner, "managedBy": "pulumi"},
)

secret = KeyVaultSecret(
    "admin-password",
    vault=key_vault_name,
    secret_name=secret_name,
    value=admin_password,
    opts=pulumi.ResourceOptions(depends_on=[resource_group]),
)

pulumi.export("environment", stack)
pulumi.export("resource_group", resource_group_name)
pulumi.export("key_vault", key_vault_name)
pulumi.export("secret_name", secret_name)
pulumi.export("adminPasswordPreview", admin_password)
pulumi.export("handoff_card", pulumi.Output.concat("Stack ", stack, " owns Resource Group ", resource_group_name))
PY

python3 -m venv venv >/dev/null
venv/bin/pip install --upgrade pip >/dev/null
venv/bin/pip install -r requirements.txt >/dev/null

cd /root/workspace/azure-consumer

cat > Pulumi.yaml <<'YAML'
name: projects-stacks-azure-consumer
runtime:
  name: python
  options:
    virtualenv: venv
description: Consume outputs from the Azure infra project through StackReference.
YAML

cat > requirements.txt <<'REQ'
pulumi>=3.0.0
REQ

cat > __main__.py <<'PY'
import pulumi

stack = pulumi.get_stack()
infra = pulumi.StackReference(f"organization/projects-stacks-azure-infra/{stack}")

pulumi.export("source_environment", infra.require_output("environment"))
pulumi.export("source_resource_group", infra.require_output("resource_group"))
pulumi.export("source_key_vault", infra.require_output("key_vault"))
pulumi.export("source_handoff_card", infra.require_output("handoff_card"))
pulumi.export("referenced_secret", infra.require_output("adminPasswordPreview"))
PY

python3 -m venv venv >/dev/null
venv/bin/pip install --upgrade pip >/dev/null
venv/bin/pip install -r requirements.txt >/dev/null

pulumi login --local >/dev/null
docker pull ghcr.io/lonegunmanb/miniblue:sha-11ef0e8 >/dev/null 2>&1 || true

echo "Azure / miniblue projects-stacks-state lab is ready in /root/workspace"