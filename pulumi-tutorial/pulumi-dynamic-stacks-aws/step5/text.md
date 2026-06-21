# 备份与配置恢复

重大变更前，至少备份两样东西：Stack 配置文件和当前 State。先为 prod 做一次备份：

```bash
cd /root/workspace && \
mkdir -p backups && \
cp Pulumi.prod.yaml backups/Pulumi.prod.before-risk.yaml && \
pulumi stack export --stack prod > backups/prod-state.before-risk.json && \
ls -lh backups
```{{exec}}

现在模拟一次高风险配置改动：把 prod 数据桶数量从 2 改成 3，并查看配置 diff。

```bash
pulumi stack select prod && \
pulumi config set --path settings.bucketCount 3 && \
git diff -- Pulumi.prod.yaml
```{{exec}}

不要直接 up。先看 preview，确认这次配置改动会新增一个数据桶：

```bash
pulumi preview --stack prod
```{{exec}}

假设评审后决定暂缓。用刚才备份的配置文件恢复，再看 preview：

```bash
cp backups/Pulumi.prod.before-risk.yaml Pulumi.prod.yaml && \
pulumi preview --stack prod
```{{exec}}

这次应该没有资源变更。State 备份文件没有被导入，因为当前只是配置误改；真正需要 state import 时，必须先确认云上资源、Stack 名称和 Backend 位置都匹配。
