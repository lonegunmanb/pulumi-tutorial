# 理解删除路径

前几步都在看“怎么创建”，这一步改看“怎么删除”。对初学者来说，关键不是背命令，而是理解：Pulumi 删除资源，不是靠你手工去调用某个 Azure API，而是仍然走同一套受管理流程。

删除前先用预览确认当前程序会发生什么：

```bash
cd /root/workspace && \
source venv/bin/activate && \
pulumi preview --diff
```{{exec}}

这里不会删除资源，因为程序里仍然声明了这些资源，所以 `preview --diff` 看到的仍然是“保持现状”。

真正的删除发生在 `pulumi destroy`：
- Engine 会先根据 State 找到当前这个 Stack 管理过哪些资源。
- 然后按依赖关系逆序处理删除。
- 对每个资源，Engine 会调用 Dynamic Provider 的 `delete()` 方法。

也就是说，Pulumi 不只是会“创建资源”，它还会负责“有秩序地回收资源”。这也是基础设施即代码比手工操作更可靠的地方之一。