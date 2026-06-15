# 选择状态后端

Pulumi 需要一个后端来保存状态。本教程使用**本地后端**，无需账号、无需联网：

```bash
pulumi login --local
```{{exec}}

确认当前后端：

```bash
pulumi whoami --verbose
```{{exec}}

输出会显示后端为本地文件（`file://`）。不要运行不带参数的 `pulumi login`，那会进入 Pulumi Cloud 登录流程。至此，你已经在 Linux 上从零完成了 Pulumi 的**安装、验证与本地后端选择**，可以开始编写第一个 Pulumi 程序了。
