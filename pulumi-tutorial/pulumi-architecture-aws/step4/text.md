# 检查状态与模拟云

先看 Pulumi State 中记录了哪些资源：

```bash
cd /root/workspace && \
pulumi stack export | jq -r '.deployment.resources[] | [.type, .urn] | @tsv'
```{{exec}}

再看 MiniStack 中真实存在的 S3 Bucket：

```bash
awslocal s3 ls
```{{exec}}

> 提示：`awslocal` 只是带上本地 endpoint 的 `aws` 包装器。如果提示 `aws: not found`（环境仍在安装 AWS CLI），可以稍等片刻重试，或直接用 `curl` 查询 MiniStack：
>
> ```bash
> curl -s http://localhost:4566/ | head
> ```{{exec}}

这一步对应本章架构图中的两条线：Engine 写 State，Provider 调用云 API。