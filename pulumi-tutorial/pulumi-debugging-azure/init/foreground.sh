#!/usr/bin/env bash
echo "正在准备 Pulumi 调试 Azure 实验环境（Pulumi、Node.js、miniblue 与依赖），请稍候……"
for _ in $(seq 1 180); do [ -f /tmp/.setup-done ] && break; sleep 2; done
[ -f /tmp/.setup-done ] && echo "环境准备完成，请进入 /root/workspace/debugging-azure 开始实验。" || echo "环境仍在准备中，若长时间未就绪可查看日志：tail -n 200 /tmp/pulumi-setup.log"