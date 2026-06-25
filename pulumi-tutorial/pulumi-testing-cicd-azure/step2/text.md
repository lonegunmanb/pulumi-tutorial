# 修复程序让测试通过

现在只做最小修改：给 Resource Group 和 Virtual Network 补齐 owner 与 managedBy 标签。

```bash
cd /root/workspace && \
cat > index.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure";

const config = new pulumi.Config();
const prefix = config.get("prefix") ?? "testing";
const location = "eastus";
const commonTags = {
  environment: "dev",
  owner: "platform-team",
  managedBy: "pulumi",
};

const miniblue = new azure.Provider("miniblue", {
  features: {},
  metadataHost: "localhost:4567",
  resourceProviderRegistrations: "none",
  subscriptionId: "00000000-0000-0000-0000-000000000000",
  tenantId: "00000000-0000-0000-0000-000000000001",
  clientId: "miniblue",
  clientSecret: "miniblue",
});

export const resourceGroup = new azure.core.ResourceGroup("app-rg", {
  name: `${prefix}-app-rg`,
  location,
  tags: commonTags,
}, { provider: miniblue });

export const virtualNetwork = new azure.network.VirtualNetwork("app-vnet", {
  name: `${prefix}-app-vnet`,
  resourceGroupName: resourceGroup.name,
  location,
  addressSpaces: ["10.20.0.0/16"],
  subnets: [{ name: "app", addressPrefixes: ["10.20.1.0/24"] }],
  tags: commonTags,
}, { provider: miniblue });

export const resourceGroupName = resourceGroup.name;
export const virtualNetworkName = virtualNetwork.name;
TS
```{{exec}}

重新运行单元测试。绿色结果说明资源输入已经满足测试写下的约束。

```bash
cd /root/workspace && \
npm run test:unit
```{{exec}}

再看一次 preview。单元测试不需要 Pulumi CLI，但 preview 会执行真实 Pulumi 入口，并通过 Azure provider 对接 miniblue。

```bash
cd /root/workspace && \
pulumi stack select dev && \
pulumi preview
```{{exec}}
