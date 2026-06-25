# 先写失败的单元测试

TDD 的第一步是先表达约束。当前程序会创建一个 S3 Bucket，但还没有完整的标签约束。

先看入口程序：

```bash
cd /root/workspace && \
sed -n '1,160p' index.ts
```{{exec}}

现在写一个 Pulumi mock 单元测试。它在导入程序前设置 mocks，然后断言 Bucket 必须允许测试环境清理，并且必须包含 owner 与 managedBy 标签。测试代码已经由初始化脚本放在 asserts 目录中，这里先查看内容，再复制到测试目录。

```bash
cd /root/workspace && \
mkdir -p test && \
cat asserts/unit.spec.ts && \
cp asserts/unit.spec.ts test/unit.spec.ts
```{{exec}}

运行测试。这里预期会失败，因为程序还没有写入 owner 和 managedBy 标签。

```bash
cd /root/workspace && \
npm run test:unit || true
```{{exec}}

红灯是有价值的：它证明测试确实能发现当前资源输入没有满足契约。下一步再改程序。