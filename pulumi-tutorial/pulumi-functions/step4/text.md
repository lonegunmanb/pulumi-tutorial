# Resource methods：EKS getKubeconfig

最后一类是 resource method：它挂在某个由 Pulumi 管理的资源上，从该资源派生出一个值。经典例子就是 `@pulumi/eks` 的 `cluster.getKubeconfig()`——从你刚建好的集群算出一份 kubeconfig。

> MiniStack 未挂载 Docker socket，因此 EKS 会回退到轻量的**静态 mock**（而不是拉起真实的 k3s 容器）。这足以演示 resource method 的用法：`getKubeconfig()` 依然会从集群派生出一份 kubeconfig，只是里面的 server / 证书是 mock 值。

先看程序：

```bash
cd /root/workspace && cat variants/step4.ts
```{{exec}}

注意结尾的 `cluster.getKubeconfig()`：它不是普通的 provider function，而是绑定在 `cluster` 实例上的方法（一个 resource method）。它一定返回 `Output`（永远是 output form），也没有 `provider`、`parent` 这类 invoke 选项——因为它的「上下文」就来自所属资源本身。

> 程序里关掉了 `vpc-cni` / `kube-proxy` / `coredns` 这几个托管插件（`useDefaultVpcCni`、`kubeProxyAddonOptions`、`corednsAddonOptions`）。原因是它们会调用 `aws:eks/getAddonVersion` 去查插件版本，而 MiniStack 没有实现这个 invoke。`getKubeconfig()` 只依赖集群的 endpoint 与证书，与这些插件无关，所以关掉不影响本步骤。

部署：

```bash
cp variants/step4.ts index.ts && pulumi up --yes
```{{exec}}

取出由 resource method 算出的 kubeconfig：

```bash
pulumi stack output kubeconfig --show-secrets | head -c 600; echo
```{{exec}}

你会看到一份 YAML/JSON 形式的 kubeconfig——它的 server 地址、证书、集群名都是从那个**已托管的 EKS 集群**派生出来的。这正是 resource method 的价值：派生值的逻辑和数据，都来自资源本身。

四类函数到此全部跑通：

- provider function（`getCallerIdentity` 的 direct / output 两形态）
- get function（`Topic.get` 引用未托管资源）
- function serialization（闭包 → Lambda）
- resource method（`cluster.getKubeconfig()`）

> 收尾（可选）：`pulumi destroy --yes`{{exec}} 清理本 stack 创建的资源，`docker compose down -v`{{exec}} 停止并清理 MiniStack。
