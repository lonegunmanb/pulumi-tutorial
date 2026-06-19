# 实验完成

你在一套本地 MiniStack 环境里，把 Pulumi 的四类函数全部跑了一遍：

| 类别 | 本实验示例 | 关键特征 |
| --- | --- | --- |
| **Provider function** | `aws.getCallerIdentity`（direct / output） | 查询一个值；output form 进依赖图，direct form 返回 Promise |
| **Get function** | `aws.sns.Topic.get(...)` | 只读引用**未托管**资源，永不改/删；接管请改用 `pulumi import` |
| **Function serialization** | `aws.lambda.CallbackFunction` | 闭包被序列化成 Lambda；捕获变量在序列化时定格；仅 Node.js |
| **Resource method** | `cluster.getKubeconfig()` | 绑定在已托管资源上的方法；永远 output form，无 invoke 选项 |

选型速记：

- 要**查一个值** → provider function（默认 output form）。
- 要**引用别人建好的资源** → get function（只读）；要**接管**它 → `pulumi import`。
- 要**把一段代码变成云函数** → function serialization（CallbackFunction）。
- 要**从某个已托管资源派生值** → 看它有没有 resource method。

回到教程正文，复习「8.6 选型决策清单」，把这套判断固化成你自己的习惯。
