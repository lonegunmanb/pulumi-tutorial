#!/usr/bin/env bash
echo "正在准备实验环境（安装 Pulumi、Docker Compose、依赖并拉取 MiniStack / k3s 镜像），请稍候……"
for _ in $(seq 1 240); do [ -f /tmp/.setup-done ] && break; sleep 2; done
[ -f /tmp/.setup-done ] && echo "环境准备完成，请进入 /root/workspace 开始 Functions 实验。" || echo "环境仍在准备中，若长时间未就绪可查看日志：tail -n 200 /tmp/pulumi-setup.log"
