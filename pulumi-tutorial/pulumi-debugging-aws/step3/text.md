# 打开 Provider 详细日志

现在故意把 S3 endpoint 指向一个错误端口，并改动标签来触发一次 Provider 调用。命令会失败，这是本步骤的观察对象。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi config set breakProvider true && \
pulumi config set diagnosticTag broken-run && \
pulumi up --yes --logtostderr --logflow -v=9 2> provider-debug.log || true
```{{exec}}

查看日志中与错误 endpoint 有关的片段，然后把配置恢复为可用状态。注意：失败过程中 provider 配置可能已经写入 State，所以恢复命令必须继续执行。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
(grep -Ei 'localhost:5999|connection refused|error updating S3 Bucket|provider=aws|diagnostic-bucket' provider-debug.log | tail -60 || true) && \
pulumi config set breakProvider false && \
pulumi config set diagnosticTag recovered && \
pulumi up --yes --diff
```{{exec}}

这个步骤展示的是 Provider 层错误。普通 Diagnostics 告诉你资源操作失败，verbose 日志帮助你确认实际访问的 endpoint、失败资源和 provider 版本。