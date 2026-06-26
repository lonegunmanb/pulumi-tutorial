# 本地策略：检查最终资源

组件能提供正确路径，但策略要检查最终资源图。先查看本地策略包：

```bash
source /root/.pulumi-best-practices-azure-env.sh && \
cd /root/workspace/best-practices-azure/policy-pack && \
sed -n '1,240p' index.ts
```{{exec}}

现在切换到绕开组件的写法。这个变体直接创建 PostgreSQL Flexible Server，故意打开公网访问，并缺少组件版本标签。

```bash
cd /root/workspace/best-practices-azure/workload && \
cp variants/insecure-direct.ts index.ts && \
sed -n '1,180p' index.ts
```{{exec}}

把策略包交给 preview。命令会失败，输出里会列出 mandatory 违规项。

```bash
pulumi preview --policy-pack ../policy-pack || true
```{{exec}}

恢复组件版本，再用同一个策略包预览：

```bash
cp variants/good.ts index.ts && \
pulumi preview --policy-pack ../policy-pack
```{{exec}}

这一步体现的是第二层防线：即使有人绕开组件，本地 Policy Pack 仍然会检查 PostgreSQL 的安全和成本属性。