# 先写失败的单元测试

TDD 的第一步是先表达约束。当前程序会创建 Resource Group 和 Virtual Network，但还没有完整的标签约束。

先看入口程序：

```bash
cd /root/workspace && \
sed -n '1,220p' index.ts
```{{exec}}

现在写一个 Pulumi mock 单元测试。它在导入程序前设置 mocks，然后断言 Resource Group 必须包含 owner 与 managedBy 标签，并且 Virtual Network 必须使用约定地址空间。

```bash
cd /root/workspace && \
mkdir -p test && \
cat > test/unit.spec.ts <<'TS'
import * as pulumi from "@pulumi/pulumi";
import { strict as assert } from "node:assert";
import "mocha";

pulumi.runtime.setMocks({
	newResource(args: pulumi.runtime.MockResourceArgs) {
		return {
			id: `${args.name}_id`,
			state: {
				...args.inputs,
				id: `/subscriptions/00000000/resourceGroups/${args.inputs.name ?? args.name}`,
			},
		};
	},
	call(args: pulumi.runtime.MockCallArgs) {
		return args.inputs;
	},
}, "pulumi-testing-cicd-azure", "dev", false);

function outputOf<T>(value: pulumi.Output<T>): Promise<T> {
	return new Promise((resolve) => value.apply(resolve));
}

describe("azure resource contract", () => {
	let infra: typeof import("../index");

	before(async () => {
		infra = await import("../index");
	});

	it("declares resource group ownership tags", async () => {
		const tags = await outputOf(infra.resourceGroup.tags);
		assert.equal(tags?.owner, "platform-team");
		assert.equal(tags?.managedBy, "pulumi");
	});

	it("uses the approved network range", async () => {
		assert.deepEqual(await outputOf(infra.virtualNetwork.addressSpaces), ["10.20.0.0/16"]);
	});
});
TS
```{{exec}}

运行测试。这里预期会失败，因为程序还没有写入 owner 和 managedBy 标签。

```bash
cd /root/workspace && \
npm run test:unit || true
```{{exec}}

红灯是有价值的：它证明测试确实能发现当前资源输入没有满足契约。下一步再改程序。
