# 阅读 Pulumi 程序

查看当前项目文件：

```bash
cd /root/workspace && \
cat Pulumi.yaml && \
sed -n '1,240p' index.ts && \
pulumi stack ls
```{{exec}}

注意 `index.ts` 中的 `new aws.s3.Bucket(...)`。它不是马上创建桶，而是把“我想要一个桶”的请求注册给 Pulumi Engine。

这里还创建了一个显式的 `aws.Provider("ministack", ...)`，让 AWS Provider 把请求发送到 MiniStack。