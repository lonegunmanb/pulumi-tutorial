# 用 Automation API 部署到 miniblue

单元测试验证了资源输入。集成测试要验证 Pulumi 生命周期本身：创建临时 Stack、预览、更新到 miniblue、读取输出、检查状态，最后销毁。

写一个 Mocha 集成测试。它使用 Automation API 操作当前目录里的 Pulumi 程序。

```bash
cd /root/workspace && \
cat > test/integration.spec.ts <<'TS'
import * as automation from "@pulumi/pulumi/automation";
import { strict as assert } from "node:assert";
import "mocha";

describe("automation api integration", function () {
  this.timeout(240_000);

  const stackName = `it-${Date.now()}`;
  let stack: automation.Stack | undefined;

  after(async () => {
    if (!stack) {
      return;
    }

    await stack.destroy({ onOutput: console.info });
    await stack.workspace.removeStack(stackName);
  });

  it("deploys a temporary stack and validates state", async () => {
    stack = await automation.LocalWorkspace.createOrSelectStack({
      stackName,
      workDir: process.cwd(),
    }, {
      envVars: {
        PULUMI_CONFIG_PASSPHRASE: "",
        TS_NODE_TRANSPILE_ONLY: "1",
        NODE_OPTIONS: "--max-old-space-size=512",
        SSL_CERT_FILE: "/root/.miniblue/cert.pem",
        ARM_CLIENT_ID: "miniblue",
        ARM_CLIENT_SECRET: "miniblue",
        ARM_SUBSCRIPTION_ID: "00000000-0000-0000-0000-000000000000",
        ARM_TENANT_ID: "00000000-0000-0000-0000-000000000001",
      },
    });

    await stack.setConfig("prefix", { value: "it" });
    await stack.preview({ onOutput: console.info });

    const result = await stack.up({ onOutput: console.info });
    assert.equal(result.outputs.resourceGroupName.value, "it-app-rg");

    const exported = await stack.exportStack();
    const resourceGroup = exported.deployment.resources.find((resource) => resource.type === "azure:core/resourceGroup:ResourceGroup");
    const virtualNetwork = exported.deployment.resources.find((resource) => resource.type === "azure:network/virtualNetwork:VirtualNetwork");

    assert.ok(resourceGroup, "expected a Resource Group resource in the deployment state");
    assert.ok(virtualNetwork, "expected a Virtual Network resource in the deployment state");
    assert.equal(resourceGroup?.inputs?.tags?.owner, "platform-team");
    assert.deepEqual(virtualNetwork?.inputs?.addressSpaces, ["10.20.0.0/16"]);
  });
});
TS
```{{exec}}

运行集成测试。第一次运行可能会下载 Azure provider 插件，因此会比单元测试慢。

```bash
cd /root/workspace && \
npm run test:integration
```{{exec}}

测试结束后，临时 Stack 会被 destroy 并删除。你可以确认当前工作区只剩 dev Stack。

```bash
cd /root/workspace && \
pulumi stack ls
```{{exec}}
