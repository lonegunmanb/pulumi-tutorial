# 查看 template 目录

后台初始化已经准备好一个本地 template。先查看目录结构和 `Pulumi.yaml`。

```bash
source /root/.pulumi-templates-env.sh && \
cd /root/workspace/templates-lab/service-template && \
find . -maxdepth 2 -type f | sort && \
sed -n '1,120p' Pulumi.yaml
```{{exec}}

注意 Pulumi.yaml 里的 template 段：displayName、description、quickstart、config 和 metadata 都是给 `pulumi new` 使用的模板元数据。