#!/usr/bin/env bash
echo "正在准备实验环境（安装 Pulumi、Docker Compose、依赖并拉取 miniblue 镜像），请稍候……"
for _ in $(seq 1 180); do
  if [ -f /tmp/.setup-done ]; then
    echo "环境准备完成。请进入 /root/workspace 开始 Azure / miniblue 版实验。"
    exit 0
  fi
  sleep 2
done
echo "环境仍在准备中。若命令报错，请稍候重试，或执行 'ls /tmp/.setup-done' 确认是否就绪。"