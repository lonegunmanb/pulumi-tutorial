# 用 azlocal 验证

这一步是在回答一个初学者最常见的问题："Pulumi 说它创建了资源，那我怎么确认这不是只写在自己内部记录里？"

答案是同时看两边：
- 一边看 **Pulumi State**，也就是 Pulumi 自己保存的部署记录。
- 一边看 **模拟 Azure** 里的真实资源。

先看 Pulumi State 中记录的资源：

```bash
cd /root/workspace && \
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv'
```{{exec}}

再用 `azlocal` 查询 `miniblue` 里真实存在的资源（两条命令拆开点击，避免互相干扰）：

```bash
azlocal group show --name pulumi-arch-rg
```{{exec}}

```bash
azlocal keyvault secret show --vault pulumi-arch-kv --name engine-token
```{{exec}}

如果这两边都能查到对应资源，就说明 Pulumi 的内部记录和模拟 Azure 里的现实资源是对齐的。

> 提示：本实验里的 Dynamic Provider 使用 `azlocal` 的默认订阅 `00000000-0000-0000-0000-000000000000` 创建资源组，所以上面无需加 `--subscription`。如果你修改过订阅，或看到 `ResourceNotFound`，请确认 `__main__.py` 中的 `SUBSCRIPTION` 与查询订阅一致（必要时 `azlocal group show --name pulumi-arch-rg --subscription <你的订阅>`）。

这里你可以顺便建立一个重要概念：**State 是 Pulumi 的“记忆”，云 API 里的资源是外部世界的“现实”**。Pulumi 每次运行时，都会试图让这两者重新一致。