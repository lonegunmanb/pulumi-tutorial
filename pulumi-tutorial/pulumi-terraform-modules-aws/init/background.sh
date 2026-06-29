#!/usr/bin/env bash
set -o pipefail

exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-terraform-modules-aws"
export SCENARIO_TITLE="使用 Terraform Module：AWS / MiniStack 版"
export SKIP_SAMPLE_PROJECT=1
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

rm -f /tmp/.setup-done

if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null || true
  chmod 600 /swapfile 2>/dev/null || true
  mkswap /swapfile >/dev/null 2>&1 || true
  swapon /swapfile >/dev/null 2>&1 || true
fi

bash /root/setup-common.sh || true
export PATH="$HOME/.pulumi/bin:$PATH"

for line in 'export PULUMI_CONFIG_PASSPHRASE=""' 'export TS_NODE_TRANSPILE_ONLY=1' 'export NODE_OPTIONS=--max-old-space-size=512' 'export AWS_ACCESS_KEY_ID=test' 'export AWS_SECRET_ACCESS_KEY=test' 'export AWS_DEFAULT_REGION=us-east-1'; do
  grep -q "$line" /root/.bashrc 2>/dev/null || echo "$line" >> /root/.bashrc
done

cat > /root/.pulumi-terraform-modules-aws-env.sh <<'SH'
export PULUMI_CONFIG_PASSPHRASE=""
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS=--max-old-space-size=512
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
SH
grep -q '.pulumi-terraform-modules-aws-env.sh' /root/.bashrc 2>/dev/null || echo 'source /root/.pulumi-terraform-modules-aws-env.sh' >> /root/.bashrc

apt-get install -y unzip jq >/dev/null 2>&1 || true
if ! command -v aws >/dev/null 2>&1; then
  if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip 2>/dev/null; then
    unzip -o -q /tmp/awscliv2.zip -d /tmp >/dev/null 2>&1 && /tmp/aws/install --update >/dev/null 2>&1
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

mkdir -p /root/workspace/terraform-modules-aws/variants
cd /root/workspace/terraform-modules-aws

cat > docker-compose.yml <<'YAML'
services:
  ministack:
    image: ministackorg/ministack:latest
    container_name: pulumi-terraform-modules-ministack
    ports:
      - "4566:4566"
    environment:
      MINISTACK_REGION: us-east-1
      MINISTACK_ACCOUNT_ID: "000000000000"
YAML

docker compose up -d >/dev/null 2>&1 || true
for attempt in $(seq 1 90); do
  if curl -sf http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    break
  fi
  if [ "$attempt" = "90" ]; then
    docker compose logs || true
    exit 1
  fi
  sleep 2
done

cat > package.json <<'JSON'
{
  "name": "terraform-modules-aws-lab",
  "version": "1.0.0",
  "private": true,
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

cat > Pulumi.yaml <<'YAML'
name: terraform-modules-aws-lab
runtime:
  name: nodejs
  options:
    nodeargs: "--max-old-space-size=512"
description: Use terraform-aws-modules/vpc/aws from Pulumi against MiniStack.
YAML

cat > variants/base.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as vpcmod from "@pulumi/vpcmod";

const stack = pulumi.getStack();

const terraformAws = new vpcmod.Provider("terraform-aws", {
  aws: {
    region: "us-east-1",
    access_key: "test",
    secret_key: "test",
    skip_credentials_validation: true,
    skip_metadata_api_check: true,
    skip_requesting_account_id: true,
    skip_region_validation: true,
    endpoints: [{
      ec2: "http://localhost:4566",
      sts: "http://localhost:4566",
    }],
  },
});

const network = new vpcmod.Module("tutorial-vpc", {
  name: `tfmod-${stack}`,
  cidr: "10.0.0.0/16",
  azs: ["us-east-1a", "us-east-1b"],
  public_subnets: ["10.0.101.0/24", "10.0.102.0/24"],
  private_subnets: ["10.0.1.0/24", "10.0.2.0/24"],
  enable_nat_gateway: false,
  enable_vpn_gateway: false,
  enable_dns_hostnames: true,
  enable_dns_support: true,
  manage_default_network_acl: false,
  manage_default_route_table: false,
  manage_default_security_group: false,
  tags: {
    Environment: stack,
    ManagedBy: "pulumi",
    Purpose: "terraform-module-lab",
  },
}, { provider: terraformAws });

export const vpcId = network.vpc_id;
export const vpcCidr = network.vpc_cidr_block;
export const publicSubnetIds = network.public_subnets;
export const privateSubnetIds = network.private_subnets;
TS

cat > variants/expanded.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as vpcmod from "@pulumi/vpcmod";

const stack = pulumi.getStack();

const terraformAws = new vpcmod.Provider("terraform-aws", {
  aws: {
    region: "us-east-1",
    access_key: "test",
    secret_key: "test",
    skip_credentials_validation: true,
    skip_metadata_api_check: true,
    skip_requesting_account_id: true,
    skip_region_validation: true,
    endpoints: [{
      ec2: "http://localhost:4566",
      sts: "http://localhost:4566",
    }],
  },
});

const network = new vpcmod.Module("tutorial-vpc", {
  name: `tfmod-${stack}`,
  cidr: "10.0.0.0/16",
  azs: ["us-east-1a", "us-east-1b", "us-east-1c"],
  public_subnets: ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"],
  private_subnets: ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"],
  enable_nat_gateway: false,
  enable_vpn_gateway: false,
  enable_dns_hostnames: true,
  enable_dns_support: true,
  manage_default_network_acl: false,
  manage_default_route_table: false,
  manage_default_security_group: false,
  tags: {
    Environment: stack,
    ManagedBy: "pulumi",
    Purpose: "terraform-module-lab-expanded",
  },
}, { provider: terraformAws });

export const vpcId = network.vpc_id;
export const vpcCidr = network.vpc_cidr_block;
export const publicSubnetIds = network.public_subnets;
export const privateSubnetIds = network.private_subnets;
TS

cp variants/base.ts index.ts
npm install --no-audit --no-fund >/dev/null 2>&1 || true
pulumi login --local >/dev/null 2>&1 || true
pulumi stack select dev >/dev/null 2>&1 || pulumi stack init dev >/dev/null 2>&1 || true

touch /tmp/.setup-done
echo "Terraform Module AWS lab is ready in /root/workspace/terraform-modules-aws"