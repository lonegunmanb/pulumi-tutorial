# 备份与网络配置恢复

重大网络变更前，先备份 Stack 配置文件和当前 State。下面为 prod 保存一份快照：

```bash
cd /root/workspace && \
mkdir -p backups && \
cp Pulumi.prod.yaml backups/Pulumi.prod.before-network-change.yaml && \
pulumi stack export --stack prod > backups/prod-state.before-network-change.json && \
ls -lh backups
```{{exec}}

现在模拟一次高风险配置改动：关闭 prod 的私有子网开关，并查看配置 diff。

```bash
pulumi stack select prod && \
pulumi config set --path settings.enablePrivateSubnet false && \
git diff -- Pulumi.prod.yaml
```{{exec}}

不要直接 up。先看 preview，确认这次改动会移除 data 子网和私有 NSG：

```bash
pulumi preview --stack prod
```{{exec}}

假设评审后决定暂缓。恢复刚才备份的配置文件，再看 preview：

```bash
cp backups/Pulumi.prod.before-network-change.yaml Pulumi.prod.yaml && \
pulumi preview --stack prod
```{{exec}}

这次应该没有资源变更。State 备份文件只作为恢复材料保存，不在这个实验里导入。
