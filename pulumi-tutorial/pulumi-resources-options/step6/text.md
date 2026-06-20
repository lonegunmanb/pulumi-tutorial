# transforms：给忘记安全组的网卡自动补默认防火墙

前面几步都在「逐个资源」地设置选项。这一步换个角度：用 `transforms` 在资源注册的瞬间批量改写它们的输入。一个典型用途就是给团队兜底——谁要是建了网卡却忘了关联安全组，就自动挂上一个默认防火墙。

为聚焦本步主题，下面的程序换成一套全新的网络资源（VPC + 子网 + 一块弹性网卡 ENI）。运行它会顺带删除前几步遗留的桶，这是预期之内的。

**1) 先看「没有 transform」时的样子**

先读这一版代码：

```bash
cat /root/workspace/variants/step6-pre.ts
```{{exec}}

里面那块 ENI 故意没有写 `securityGroups`，而且没有注册任何 transform。应用它：

```bash
cd /root/workspace && cp variants/step6-pre.ts index.ts && pulumi up --yes
```{{exec}}

看看这块网卡关联了哪些安全组，再看看我们准备好的默认防火墙的 id：

```bash
pulumi stack output eniSecurityGroups; echo -n "default-fw = "; pulumi stack output defaultFwId
```{{exec}}

你会发现网卡上并没有挂着我们的默认防火墙——它要么是空的，要么是模拟器随手分配的另一个安全组。

**2) 加一段 transform，自动补默认防火墙**

再读改动后的代码：

```bash
cat /root/workspace/variants/step6.ts
```{{exec}}

它只比上一版多了一段 `pulumi.runtime.registerResourceTransform(...)`。这个回调拦截每一个类型为 `aws:ec2/networkInterface:NetworkInterface` 的资源，发现它没有安全组，就把输入里的安全组列表设成默认防火墙。应用它：

```bash
cp variants/step6.ts index.ts && pulumi up --yes
```{{exec}}

`pulumi up` 会显示这块网卡被更新——它关联的安全组变成了我们的默认防火墙。再看一次输出确认：

```bash
pulumi stack output eniSecurityGroups; echo -n "default-fw = "; pulumi stack output defaultFwId
```{{exec}}

现在 `eniSecurityGroups` 里出现了 `defaultFwId` 的值。注意：我们既没有改 ENI 的声明，也没有逐个资源加选项，只是注册了一条规则，就让所有「缺省安全组的网卡」统一拿到了兜底防火墙——这正是 transform 的价值。

**3) 清理环境**

```bash
pulumi destroy --yes && docker compose down
```{{exec}}

至此本实验覆盖的资源选项有：`deleteBeforeReplace`、`replaceOnChanges`、`dependsOn`、`aliases`、`protect`、`ignoreChanges`，以及这一步的 `transforms`。
