# 完成

你已经完成 AWS 版 Pulumi 调试实验。

这次你练习了：

- 用 preview 定位缺失 Stack 配置。
- 用程序日志观察 Pulumi 代码执行分支。
- 用 verbose logging 定位错误 Provider endpoint。
- 用 awslocal 制造标签漂移。
- 用 refresh 和 up 让 State 与真实资源重新一致。
- 导出 State 与 preview 日志，模拟 CI 排障制品。

可以用下面的命令清理实验资源：

```bash
source /root/.pulumi-debugging-aws-env.sh && \
cd /root/workspace/debugging-aws && \
pulumi destroy --yes && \
pulumi stack rm dev --yes
```{{exec}}