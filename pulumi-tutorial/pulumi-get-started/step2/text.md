# 预览与部署

先预览资源图，再部署并查看输出：

```bash
pulumi preview
pulumi up --yes
pulumi stack output
```{{exec}}

完成后销毁资源：

```bash
pulumi destroy --yes
```{{exec}}

观察 Pulumi 如何在本地状态中记录资源快照。