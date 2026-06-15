#!/usr/bin/env bash
set -euo pipefail
export SCENARIO_ID="pulumi-get-started"
export SCENARIO_TITLE="在 Linux 上安装 Pulumi"
# 本实验由学员亲手安装 Pulumi CLI，因此跳过预装与示例项目。
export SKIP_PULUMI_INSTALL=1
export SKIP_SAMPLE_PROJECT=1
/root/setup-common.sh