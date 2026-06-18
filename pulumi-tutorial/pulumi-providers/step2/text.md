# Any Terraform Provider

Pulumi Registry 没有 `hashicorp/local` 的官方包，但它有 Terraform provider。**Any Terraform Provider** 能把它现场生成成一个本地 Pulumi SDK。

初始化阶段已经替你执行过一次 `pulumi package add`，你可以再跑一次确认它的效果（命令是幂等的）：

```bash
cd /root/workspace && pulumi package add terraform-provider hashicorp/local
```{{exec}}

看它往 `Pulumi.yaml` 里写了什么，以及本地 SDK 生成在哪：

```bash
cat Pulumi.yaml && echo '---' && ls sdks
```{{exec}}

`Pulumi.yaml` 的 `packages` 段记录了 `source: terraform-provider` 与参数 `hashicorp/local`，`sdks/` 下是现生成的强类型 SDK。

现在切换到使用它的程序——用这个 Terraform provider 在本地写出一个文件：

```bash
cp variants/step2.ts index.ts && pulumi up --yes
```{{exec}}

`step2.ts` 里 `import * as local from "@pulumi/local"`，然后 `new local.File(...)`。部署完成后看文件确实被写出来了：

```bash
cat output/greeting.txt
```{{exec}}

要点：

- `pulumi package add terraform-provider <author>/<name>` 把**任意** Terraform/OpenTofu provider 变成本地 Pulumi SDK，有自动补全、类型检查，体验和官方包一样。
- 默认从 OpenTofu registry 拉取（与 Terraform registry 兼容）。生产中应**钉死版本**：`pulumi package add terraform-provider hashicorp/local 2.5.1`。
- 团队成员克隆仓库后用 `pulumi install` 即可按 `Pulumi.yaml` 的 `packages` 补齐 SDK 与 provider 二进制。
- 这一步证明了：即便 Registry 没有现成 Pulumi 包，只要存在 Terraform provider，你就能在 Pulumi 里用上它。
