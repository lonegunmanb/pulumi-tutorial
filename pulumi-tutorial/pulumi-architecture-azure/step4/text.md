# 用 azlocal 验证

先看 Pulumi State 中记录的资源：

```bash
cd /root/workspace
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv'
```{{exec}}

再用 `azlocal` 查询 miniblue（两条命令拆开点击，避免互相干扰）：

```bash
azlocal group show --name pulumi-arch-rg
```{{exec}}

```bash
azlocal keyvault secret show --vault pulumi-arch-kv --name engine-token
```{{exec}}

这说明 Pulumi State 与 Azure 模拟器里的现实资源已经对齐。

> 提示：本实验里的 Dynamic Provider 使用 `azlocal` 的默认订阅 `00000000-0000-0000-0000-000000000000` 创建资源组，所以上面无需加 `--subscription`。如果你修改过订阅，或看到 `ResourceNotFound`，请确认 `__main__.py` 中的 `SUBSCRIPTION` 与查询订阅一致（必要时 `azlocal group show --name pulumi-arch-rg --subscription <你的订阅>`）。