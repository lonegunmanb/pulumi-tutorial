#!/usr/bin/env bash
# 一键从 step5 开始测试 pulumi-config 实验的 Go 版本。
#
# 用法（在 Killercoda 该实验的终端里，或等价的 Ubuntu root 环境里）：
#   bash test-config-step5.sh
#
# 它会：跳过 step1-4，确保 MiniStack 与 Go 工具链就绪，然后把 step5 的
# dev / prod 两次部署完整跑一遍，最后对比两个 Stack 的产出。
# 如果你想手动逐条执行，文件末尾的注释里列了 step5 的原始命令。
set -uo pipefail

WORKDIR_GO="/root/workspace-go"

# Pulumi / Go 的运行环境（background.sh 已写进 .bashrc，这里再导一次，确保当前 shell 可用）。
# /usr/local/go/bin 必须前置，否则镜像自带的老版 go 1.18 会抢在前面。
export PATH="/usr/local/go/bin:$HOME/.pulumi/bin:$PATH"
export GOPATH="${GOPATH:-/root/go}"
export GOFLAGS="${GOFLAGS:--mod=mod}"
export PULUMI_CONFIG_PASSPHRASE="${PULUMI_CONFIG_PASSPHRASE:-}"

echo "==> [1/5] 等待场景初始化（init/background.sh）完成"
for i in $(seq 1 120); do
  [ -f /tmp/.setup-done ] && break
  sleep 2
done
if [ ! -f "$WORKDIR_GO/main.go" ]; then
  echo "找不到 $WORKDIR_GO/main.go。"
  echo "说明：step5 的 Go 项目由本实验的 init/background.sh 生成。"
  echo "请确认你已经进入 pulumi-config 这个 Killercoda 场景（背景脚本会自动初始化），"
  echo "或稍等片刻后重试。"
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

echo "==> [3/5] 确保 Go 已安装并预热编译缓存（首次较慢，请耐心等待）"
# 不能只判断 go 是否存在——镜像或旧会话可能留下 go 1.18。
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q 'go1.23.4'; then
  echo "Go 1.23.4 尚未就绪，正在安装 go1.23.4…"
  curl -fsSL https://go.dev/dl/go1.23.4.linux-amd64.tar.gz -o /tmp/go.tgz \
    && rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tgz
fi
export PATH="/usr/local/go/bin:$PATH"
hash -r 2>/dev/null || true
/usr/local/go/bin/go version
cd "$WORKDIR_GO"
/usr/local/go/bin/go mod tidy
/usr/local/go/bin/go build -o /tmp/go-warm .
echo "Go 编译缓存已就绪。"

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
echo "✅ step5（Go 版）测试完成：dev = 3 个 dev-bucket-*（owner=platform-team），prod = 4 个 prod-bucket-*（owner=prod-team）。"
echo "重新测试可直接再次运行本脚本（pulumi up 幂等）。"
echo "清理：cd $WORKDIR_GO && pulumi destroy --yes --stack dev ; pulumi destroy --yes --stack prod"

# ----------------------------------------------------------------------------
# 如果你想像学员一样手动逐条执行 step5，这些就是原始命令：
#
#   cd /root/workspace-go && cat main.go
#   cat Pulumi.yaml
#   cd /root/workspace-go && \
#   if ! /usr/local/go/bin/go version 2>/dev/null | grep -q 'go1.23.4'; then curl -fsSL https://go.dev/dl/go1.23.4.linux-amd64.tar.gz -o /tmp/go.tgz && rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tgz; fi && \
#   export PATH=/usr/local/go/bin:$PATH && \
#   export GOPATH=/root/go && \
#   export GOFLAGS=-mod=mod && \
#   hash -r && \
#   /usr/local/go/bin/go version && \
#   /usr/local/go/bin/go mod tidy
#   pulumi stack select dev && pulumi up --yes --non-interactive && pulumi stack output
#   pulumi stack init prod
#   pulumi config set bucketPrefix prod && \
#   pulumi config set bucketCount 4 && \
#   pulumi config set aws:region us-west-2 && \
#   pulumi config set owner prod-team
#   pulumi up --yes --non-interactive && pulumi stack output
#   echo '--- dev ---' && pulumi stack output --stack dev bucketNames && \
#   echo '--- prod ---' && pulumi stack output --stack prod bucketNames
# ----------------------------------------------------------------------------
