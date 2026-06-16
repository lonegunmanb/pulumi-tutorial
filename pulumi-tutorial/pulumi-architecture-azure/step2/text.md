# 阅读 Dynamic Provider

查看 Pulumi Python 程序：

```bash
cd /root/workspace && \
cat Pulumi.yaml && \
sed -n '1,260p' __main__.py
```{{exec}}

注意：这里没有使用官方 `pulumi-azure-native` Provider，而是用 Dynamic Provider 自己实现 `create()` 和 `delete()`。这样设计不是为了替代正式生产用法，而是为了让你看清 Provider 的本质：它接收 Engine 的资源生命周期操作，再把这些操作翻译成目标平台 API 调用。