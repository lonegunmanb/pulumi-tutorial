#!/usr/bin/env bash
set -o pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-architecture-azure"
export SCENARIO_TITLE="Pulumi 架构解析：Azure / miniblue 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""

mkdir -p /root/workspace

# 安装 Pulumi、Node.js 与共享工具（尽力而为，单步失败不影响后续）。
bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

if ! grep -q 'PULUMI_CONFIG_PASSPHRASE' /root/.bashrc 2>/dev/null; then
  echo 'export PULUMI_CONFIG_PASSPHRASE=""' >> /root/.bashrc
fi

# Dynamic Provider 示例需要的 Python venv 与 pip，失败不致命。
apt-get install -y python3-pip python3-venv jq >/dev/null 2>&1 || true

# Killercoda 已预装 Docker，这里只确保守护进程在运行。
service docker start >/dev/null 2>&1 || true

if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/workspace
cd /root/workspace

cat > docker-compose.yml <<'YAML'
services:
  miniblue:
    image: ghcr.io/lonegunmanb/miniblue:sha-11ef0e8
    container_name: pulumi-arch-miniblue
    ports:
      - "4566:4566"
      - "4567:4567"
    environment:
      LOG_LEVEL: info
YAML

cat > Pulumi.yaml <<'YAML'
name: pulumi-architecture-azure
runtime: python
description: Understand Pulumi architecture with Dynamic Providers and miniblue.
YAML

cat > requirements.txt <<'REQ'
pulumi>=3.0.0
requests>=2.31.0
REQ

cat > __main__.py <<'PY'
import requests
import pulumi
from pulumi.dynamic import Resource, ResourceProvider, CreateResult

MINIBLUE_URL = "http://localhost:4566"
# 使用 azlocal 的默认订阅，便于后续用 `azlocal group show` 直接查询（无需 --subscription）。
SUBSCRIPTION = "00000000-0000-0000-0000-000000000000"


class ResourceGroupProvider(ResourceProvider):
    def create(self, props):
        name = props["name"]
        location = props.get("location", "eastus")
        response = requests.put(
            f"{MINIBLUE_URL}/subscriptions/{SUBSCRIPTION}/resourcegroups/{name}",
            json={"location": location, "tags": props.get("tags", {})},
            timeout=10,
        )
        response.raise_for_status()
        outs = dict(props)
        outs["miniblue_url"] = MINIBLUE_URL
        return CreateResult(id_=name, outs=outs)

    def delete(self, id, props):
        requests.delete(
            f"{MINIBLUE_URL}/subscriptions/{SUBSCRIPTION}/resourcegroups/{id}",
            timeout=10,
        )


class ResourceGroup(Resource):
    def __init__(self, resource_name, name, location="eastus", tags=None, opts=None):
        super().__init__(
            ResourceGroupProvider(),
            resource_name,
            {"name": name, "location": location, "tags": tags or {}},
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
        return CreateResult(
            id_=f"{props['vault']}/{props['secret_name']}",
            outs=dict(props),
        )

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


rg = ResourceGroup(
    "architecture-rg",
    name="pulumi-arch-rg",
    location="eastus",
    tags={"managed-by": "pulumi", "chapter": "architecture"},
)

secret = KeyVaultSecret(
    "engine-token",
    vault="pulumi-arch-kv",
    secret_name="engine-token",
    value="language-host-to-engine",
    opts=pulumi.ResourceOptions(depends_on=[rg]),
)

pulumi.export("resource_group", "pulumi-arch-rg")
pulumi.export("key_vault", "pulumi-arch-kv")
pulumi.export("secret_name", "engine-token")
pulumi.export("miniblue_url", MINIBLUE_URL)
PY

python3 -m venv venv >/dev/null 2>&1 || true
venv/bin/pip install --upgrade pip >/dev/null 2>&1 || true
venv/bin/pip install -r requirements.txt >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true
docker pull ghcr.io/lonegunmanb/miniblue:sha-11ef0e8 >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Azure / miniblue lab is ready in /root/workspace"