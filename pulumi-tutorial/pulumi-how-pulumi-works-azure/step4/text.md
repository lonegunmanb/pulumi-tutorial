# 逻辑名变化产生 create/delete

这一步只做预览，不真正执行。我们把 content-rg 的逻辑名改成 app-rg：

```bash
cd /root/workspace && cp variants/step4-rename.ts index.ts && cat index.ts
```{{exec}}

预览这次逻辑名变化：

```bash
pulumi preview --diff
```{{exec}}

你会看到一个新资源显示加号，旧的 content-rg 显示减号。逻辑名参与 URN，所以 Pulumi 会把它们视为两个不同资源身份。

把程序恢复到上一步的更新版，方便下一步继续：

```bash
cp variants/step3-update.ts index.ts
```{{exec}}

生产环境中如果只是想安全改名，应该使用 aliases 选项。这里先只观察默认行为，后面的资源章节会专门练习安全迁移。