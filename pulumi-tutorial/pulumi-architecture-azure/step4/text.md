# 用 azlocal 验证

先看 Pulumi State 中记录的资源：

```bash
cd /root/workspace
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv'
```{{exec}}

再用 `azlocal` 查询 miniblue：

```bash
azlocal group show --name pulumi-arch-rg
azlocal keyvault secret show --vault pulumi-arch-kv --name engine-token
```{{exec}}

这说明 Pulumi State 与 Azure 模拟器里的现实资源已经对齐。