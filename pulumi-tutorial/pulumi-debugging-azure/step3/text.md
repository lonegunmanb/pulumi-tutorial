# 打开 Provider 详细日志

现在故意把 metadata endpoint 指向一个错误端口，并改动标签来触发一次 Provider 调用。命令会失败，这是本步骤的观察对象。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
pulumi config set breakProvider true && \
pulumi config set diagnosticTag broken-run && \
pulumi up --yes --logtostderr --logflow -v=9 2> provider-debug.log || true
```{{exec}}

查看日志中与错误 endpoint 有关的片段，然后把配置恢复为可用状态。

```bash
source /root/.pulumi-debugging-azure-env.sh && \
cd /root/workspace/debugging-azure && \
(grep -Ei 'localhost:5999|metadata|connection|refused|error|diagnostic-rg' provider-debug.log | tail -40 || true) && \
pulumi config set breakProvider false && \
pulumi config set diagnosticTag recovered && \
pulumi up --yes --diff
```{{exec}}

这个步骤展示的是 Provider 层错误。普通 Diagnostics 告诉你资源操作失败，verbose 日志帮助你确认实际访问的 metadata host。