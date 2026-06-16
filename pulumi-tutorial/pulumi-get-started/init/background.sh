#!/usr/bin/env bash
set -euo pipefail

# 初始化全过程日志，排查长时间未就绪时可执行：tail -n 200 /tmp/pulumi-setup.log
exec >>/tmp/pulumi-setup.log 2>&1
echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 开始 ====="
trap 'echo "[$(date +%Y-%m-%dT%H:%M:%S)] 命令失败：行 $LINENO，退出码 $?"' ERR
trap 'echo "===== [$(date +%Y-%m-%dT%H:%M:%S)] background.sh 结束，退出码 $? ====="' EXIT

export SCENARIO_ID="pulumi-get-started"
export SCENARIO_TITLE="在 Linux 上安装 Pulumi"
# 本实验由学员亲手安装 Pulumi CLI，因此跳过预装与示例项目。
export SKIP_PULUMI_INSTALL=1
export SKIP_SAMPLE_PROJECT=1
/root/setup-common.sh