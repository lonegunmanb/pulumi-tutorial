# 体验资源保护

打开 `index.ts`，给资源增加 `protect: true` 选项，然后执行：

```bash
pulumi up --yes
pulumi destroy --yes
```{{exec}}

观察 Pulumi 如何阻止受保护资源被删除。实验结束前可以移除保护并再次销毁。