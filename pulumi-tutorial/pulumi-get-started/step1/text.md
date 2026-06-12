# 检查项目结构

进入工作目录并查看自动生成的 Pulumi 项目：

```bash
cd /root/workspace
ls -la
cat Pulumi.yaml
cat index.ts
pulumi stack ls
```{{exec}}

注意 `Pulumi.yaml` 描述项目，`index.ts` 描述资源，`dev` 是当前堆栈。