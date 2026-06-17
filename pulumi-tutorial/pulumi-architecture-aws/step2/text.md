# 阅读 Pulumi 程序

这一步我们来看 Pulumi 程序的结构。Pulumi 用代码来描述你想要的基础设施，而不是通过点击网页界面或编写 YAML 配置。

查看项目文件与程序入口：

```bash
cd /root/workspace && \
cat Pulumi.yaml && \
sed -n '1,240p' index.ts && \
pulumi stack ls
```{{exec}}

重点说明：
- **Pulumi.yaml**：描述此 Pulumi Project 的元信息（项目名、运行时等）。
- **index.ts**：Pulumi 程序的入口代码，用 TypeScript 编写。其中 `new aws.s3.Bucket(...)` 表示"我想要创建一个 S3 存储桶"，但注意这行代码执行时**不会立即创建**，而是把这个请求注册给 Pulumi Engine，由引擎统一规划和执行。
- **aws.Provider("ministack", ...)**：这里显式地指定 AWS Provider 应该向 `localhost:4566` 这个本地模拟器发送请求，而非真实的 AWS。这样 Pulumi 会把所有资源创建请求转发给 MiniStack。
- **pulumi stack ls**：列出当前 Project 下所有的 Stack（环境），让你确认当前工作区的 Stack 情况。