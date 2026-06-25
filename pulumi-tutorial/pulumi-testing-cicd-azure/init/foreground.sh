#!/usr/bin/env bash
for _ in $(seq 1 180); do [ -f /tmp/.setup-done ] && break; sleep 2; done
if [ -f /tmp/.setup-done ]; then
	echo "环境准备完成，请进入 /root/workspace 开始 Azure / miniblue 版测试驱动开发实验。"
else
	echo "环境仍在准备中，若长时间未就绪可查看日志：tail -n 200 /tmp/pulumi-setup.log"
fi
