#!/usr/bin/env bash
# 一键从 step5 开始测试 pulumi-config 实验的 TypeScript 版本。
#
# 用法（在 Killercoda 该实验的终端里，或等价的 Ubuntu root 环境里）：
#   bash test-config-step5.sh
#
# 它会：跳过 step1-4，确保 MiniStack 就绪，切换到 step5 的 TypeScript 程序，
# 然后把 dev / prod 两次部署完整跑一遍，最后对比两个 Stack 的产出。
set -uo pipefail

WORKDIR="/root/workspace"

export PATH="$HOME/.pulumi/bin:$PATH"
export PULUMI_CONFIG_PASSPHRASE="${PULUMI_CONFIG_PASSPHRASE:-}"
export TS_NODE_TRANSPILE_ONLY=1
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=512}"

echo "==> [1/5] 等待场景初始化（init/background.sh）完成"
for i in $(seq 1 120); do
  [ -f /tmp/.setup-done ] && break
  sleep 2
done
if [ ! -f "$WORKDIR/variants/step5.ts" ]; then
  echo "找不到 $WORKDIR/variants/step5.ts。"
  echo "说明：step5 的 TypeScript 项目由本实验的 init/background.sh 生成。"
  echo "请确认你已经进入 pulumi-config 这个 Killercoda 场景，或稍等片刻后重试。"
  exit 1
fi

echo "==> [2/5] 等待 MiniStack 就绪"
for i in $(seq 1 60); do
  if curl -fs http://localhost:4566/_ministack/health >/dev/null 2>&1; then
    echo "MiniStack 已就绪。"
    break
  fi
  sleep 2
done

cd "$WORKDIR"

echo "==> [3/5] 检查 pulumi-config 场景是否仍使用窄导入"
if grep -R '^[[:space:]]*import .* from "@pulumi/aws";' variants index.ts >/dev/null 2>&1; then
  echo "检测到宽导入 import ... from \"@pulumi/aws\"。请改用 @pulumi/aws/s3 与 @pulumi/aws/provider。"
  exit 1
fi
cp variants/step5.ts index.ts

echo "==> [4/5] 部署 dev（应读到项目级默认 owner=platform-team）"
pulumi stack select dev 2>/dev/null || pulumi stack init dev
pulumi config set bucketPrefix dev
pulumi config set bucketCount 3
pulumi up --yes --non-interactive
pulumi stack output

echo "==> [5/5] 部署 prod（覆盖配置：prefix=prod, count=4, owner=prod-team）"
pulumi stack select prod 2>/dev/null || pulumi stack init prod
pulumi config set bucketPrefix prod
pulumi config set bucketCount 4
pulumi config set aws:region us-west-2
pulumi config set owner prod-team
pulumi up --yes --non-interactive
pulumi stack output

echo
echo "==> 对比两个 Stack 的 bucketNames"
echo '--- dev ---';  pulumi stack output --stack dev  bucketNames
echo '--- prod ---'; pulumi stack output --stack prod bucketNames

echo
echo "step5（TypeScript 版）测试完成：dev = 3 个 dev-bucket-*（owner=platform-team），prod = 4 个 prod-bucket-*（owner=prod-team）。"
echo "重新测试可直接再次运行本脚本（pulumi up 幂等）。"
echo "清理：cd $WORKDIR && pulumi destroy --yes --stack dev ; pulumi destroy --yes --stack prod ; docker compose down"

# ----------------------------------------------------------------------------
# 如果你想像学员一样手动逐条执行 step5，这些就是原始命令：
#
#   cd /root/workspace && cp variants/step5.ts index.ts && cat index.ts
#   cat Pulumi.yaml
#   pulumi stack select dev && \
#   pulumi config set bucketPrefix dev && \
#   pulumi config set bucketCount 3
#   pulumi up --yes --non-interactive && pulumi stack output
#   pulumi stack select prod || pulumi stack init prod
#   pulumi config set bucketPrefix prod && \
#   pulumi config set bucketCount 4 && \
#   pulumi config set aws:region us-west-2 && \
#   pulumi config set owner prod-team
#   pulumi up --yes --non-interactive && pulumi stack output
#   echo '--- dev ---' && pulumi stack output --stack dev bucketNames && \
#   echo '--- prod ---' && pulumi stack output --stack prod bucketNames
# ----------------------------------------------------------------------------