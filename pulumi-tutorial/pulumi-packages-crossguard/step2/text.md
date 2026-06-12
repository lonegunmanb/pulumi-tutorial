# 策略检查思路

正式章节会创建 Policy Pack，并在 Preview 阶段检查资源命名、标签和危险配置。

现在先导出资源图：

```bash
pulumi stack export > state.json
jq '.deployment.resources[] | {type, urn}' state.json
```{{exec}}