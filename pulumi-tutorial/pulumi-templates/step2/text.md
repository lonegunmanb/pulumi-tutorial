# 用 pulumi new 生成项目

现在离开 template 目录，在另一个空目录里使用本地路径生成项目。

```bash
source /root/.pulumi-templates-env.sh && \
cd /root/workspace/templates-lab && \
rm -rf orders-service && \
mkdir orders-service && \
cd orders-service && \
pulumi new ../service-template \
  --name orders-service \
  --description "Orders service generated from a local template" \
  --stack dev \
  --yes \
  --config serviceName=orders \
  --config owner=payments-team \
  --config apiToken=tok_example_12345 && \
pulumi config set --secret apiToken tok_example_12345
```{{exec}}

这一步演示本地测试模板的推荐方式：不要在 template 目录里运行，而是在新的目标目录里执行 `pulumi new`。这里为了让命令一次点击即可完成，先用 config 参数传值，再立刻把 apiToken 重写为 secret 配置；交互式使用模板时，template 里的 secret 标记会用于配置提示。
