#!/usr/bin/env bash
# 等待后台初始化完成（最多约 12 分钟），再提示学员开始。
for _ in $(seq 1 360); do [ -f /tmp/.setup-done ] && break; sleep 2; done
[ -f /tmp/.setup-done ] && echo "环境准备完成，请进入 /root/workspace 开始 AWS / MiniStack 版实验。" || echo "环境仍在准备中，若长时间未就绪可查看日志：tail -n 200 /tmp/pulumi-setup.log"