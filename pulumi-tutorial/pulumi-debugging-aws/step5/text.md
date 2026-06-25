# 导出 State 与归档日志

最后模拟 CI 排障时应保留的制品。先导出 URN 列表和 State，再用 jq 查看资源摘要。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
mkdir -p ci-artifacts && \
pulumi stack --show-urns > ci-artifacts/urns.txt && \
pulumi stack export --file ci-artifacts/state.json && \
jq '{resourceCount: (.deployment.resources | length), resources: [.deployment.resources[] | {type, urn, id}]}' ci-artifacts/state.json
```{{exec}}

再保存一次非交互 preview 日志。真实流水线里，可以把这些文件作为构建制品保存。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi preview --diff --non-interactive > ci-artifacts/preview.log && \
ls -lh ci-artifacts && \
tail -n 30 ci-artifacts/preview.log
```{{exec}}

State 文件可能包含敏感输出的密文和资源结构。共享前应先确认团队的脱敏要求。