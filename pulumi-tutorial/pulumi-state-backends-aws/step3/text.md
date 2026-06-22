# 固定 Backend URL 并创建 prod

除了手动执行登录，Pulumi 还允许把 Backend URL 写入项目文件。实验目录里已经准备了一份带 backend 字段的项目文件。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-aws && \
cp Pulumi.with-backend.yaml Pulumi.yaml && \
cat Pulumi.yaml && \
unset PULUMI_BACKEND_URL && \
pulumi whoami -v
```{{exec}}

上面的命令只取消了当前 shell 里的 PULUMI_BACKEND_URL。因为刚才已经把同一个 S3 Backend URL 写进了 Pulumi.yaml 的 backend.url，Pulumi 会从项目文件继续读取这个地址；而 step1 的 login 已经把访问这个 Backend 所需的登录记录写入了本机 Pulumi 凭据文件。

现在创建 prod Stack。它与 dev 共用同一个 Backend，但拥有独立配置和独立 State。

```bash
source /root/.pulumi-state-env.sh && \
cd /root/workspace/state-backends-aws && \
(pulumi stack select prod 2>/dev/null || pulumi stack init prod) && \
pulumi config set service checkout && \
pulumi config set owner platform-team && \
pulumi config set --secret operatorToken prod-token-456 && \
pulumi up --yes && \
pulumi stack ls
```{{exec}}

同一个 Backend 中可以有多个 Stack。新建的 DIY Backend 默认按 Project 组织 Stack，所以 dev 与 prod 都会放在 state-backends-aws 这个项目路径下，我们将在下一步的实验中验证它。
