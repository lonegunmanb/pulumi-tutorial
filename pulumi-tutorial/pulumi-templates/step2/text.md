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
  --config apiToken=tok_example_12345
```{{exec}}

这一步演示本地测试模板的推荐方式：不要在 template 目录里运行，而是在新的目标目录里执行 `pulumi new`。