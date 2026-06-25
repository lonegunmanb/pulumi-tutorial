# 定位缺失 Stack 配置

先查看当前 Pulumi 程序。它只读取两个必填配置，不加载 AWS provider。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
sed -n '1,180p' index.ts && \
pulumi stack select dev
```{{exec}}

这个程序用 `Config.require` 读取 owner 和 environment。当前 Stack 暂时没有配置；在进入 preview 之前，先用 CLI 做一次配置预检，把缺失项明确打印出来。

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi config && \
bash -lc 'missing=0; for key in owner environment; do if pulumi config get "$key" >/dev/null 2>&1; then value=$(pulumi config get "$key"); echo "OK: $key=$value"; else echo "MISSING: debugging-aws:$key"; missing=1; fi; done; test "$missing" -eq 0' || true
```{{exec}}

这里的重点不是 S3，也不是 MiniStack，而是先确认 Stack 配置是否满足程序的必填项。下一步会补齐配置，并切换到真实资源程序运行 preview。