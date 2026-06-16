# 理解删除路径

删除前先用预览确认会发生什么：

```bash
cd /root/workspace && \
source venv/bin/activate && \
pulumi preview --diff
```{{exec}}

这里不会删除资源，因为程序仍然注册了它们。真正删除发生在 `pulumi destroy` 中：Engine 会根据 State 找到已管理资源，并调用 Dynamic Provider 的 `delete()` 方法。