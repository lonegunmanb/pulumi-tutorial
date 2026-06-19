# transforms：给忘记 NSG 的子网自动关联默认 NSG

前面几步都在「逐个资源」地设置选项。这一步换个角度：用 `transforms` 在资源注册的瞬间批量改写它们的输入。一个典型用途就是给团队兜底——谁要是建了虚拟网络却忘了给子网关联 NSG，就自动关联一个默认 NSG。

为聚焦本步主题，下面的程序换成一套全新的网络资源（资源组 + VNet + 一个内联子网 + 一个默认 NSG）。运行它会顺带删除前几步遗留的资源组，这是预期之内的。

**1) 先看「没有 transform」时的样子**

先读这一版代码：

```bash
cat /root/workspace/variants/step6-pre.ts
```{{exec}}

里面 VNet 的内联子网故意没有写 `securityGroup`，而且没有注册任何 transform。应用它：

```bash
cd /root/workspace && cp variants/step6-pre.ts index.ts && pulumi up --yes
```{{exec}}

看看子网当前关联了哪个 NSG，再看看我们准备好的默认 NSG 的 id：

```bash
pulumi stack output vnetSubnets; echo "default-nsg ="; pulumi stack output defaultNsgId
```{{exec}}

你会看到子网的 `securityGroup` 字段是空的——它没有关联任何 NSG。

**2) 加一段 transform，自动关联默认 NSG**

再读改动后的代码：

```bash
cat /root/workspace/variants/step6.ts
```{{exec}}

它只比上一版多了一段 `pulumi.runtime.registerResourceTransform(...)`。这个回调拦截每一个类型为 `azure:network/virtualNetwork:VirtualNetwork` 的资源，遍历它的内联子网，把没有关联 NSG 的子网补上默认 NSG。应用它：

```bash
cp variants/step6.ts index.ts && pulumi up --yes
```{{exec}}

`pulumi up` 会显示这个 VNet 被更新——子网关联上了我们的默认 NSG。再看一次输出确认：

```bash
pulumi stack output vnetSubnets; echo "default-nsg ="; pulumi stack output defaultNsgId
```{{exec}}

现在子网的 `securityGroup` 字段填上了 `defaultNsgId` 的值。注意：我们既没有改 VNet 的声明，也没有逐个子网加配置，只是注册了一条规则，就让所有「缺省 NSG 的子网」统一拿到了兜底 NSG——这正是 transform 的价值。

**3) 清理环境**

```bash
pulumi destroy --yes && docker compose down
```{{exec}}

至此本实验覆盖的资源选项有：`deleteBeforeReplace`、`replaceOnChanges`、`dependsOn`、`aliases`、`protect`、`ignoreChanges`，以及这一步的 `transforms`。与 AWS 版相比，唯一的差别只是 provider 与资源类型，Pulumi 引擎层面的语义完全一致。
