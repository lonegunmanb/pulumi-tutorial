# Get functions：引用未托管资源

**Get function** 用来引用一个**已经存在、但不归 Pulumi 管理**的资源——只读，Pulumi 永远不会去改它、删它。

先用 AWS CLI（绕过 Pulumi）在 MiniStack 里建一个 SNS Topic，并把它的 ARN 写进 Pulumi 配置。这个 Topic 就是我们的「未托管资源」：

```bash
cd /root/workspace && \
TOPIC_ARN=$(awslocal sns create-topic --name fn-preexisting-topic --query TopicArn --output text) && \
echo "未托管 Topic ARN: $TOPIC_ARN" && \
pulumi config set preexistingTopicArn "$TOPIC_ARN"
```{{exec}}

看看程序怎么用 `get` 把它读进来：

```bash
cat variants/step2.ts
```{{exec}}

`aws.sns.Topic.get("preexisting", topicArn)` 把那个未托管 Topic 读进程序；随后我们用它的 `arn` 作为输入，创建**由 Pulumi 管理**的一个 SQS 队列和一个订阅。部署：

```bash
cp variants/step2.ts index.ts && pulumi up --yes
```{{exec}}

注意 `pulumi up` 的摘要：只创建了 `fn-demo-queue` 和 `fn-demo-sub`（`+ 2 created`），**那个 SNS Topic 不在创建列表里**——因为它是 `get` 进来的，Pulumi 不管它的生命周期。查看输出：

```bash
pulumi stack output
```{{exec}}

`unmanagedTopicArn` / `unmanagedTopicName` 来自那个未托管 Topic，`managedQueueUrl` 是新建的托管队列。

要点：

- `get` 只**读**既有资源，绝不修改或删除它。
- 如果你真的想**接管**既有资源（让 Pulumi 管它），那不是 `get`，而是 `pulumi import`。
- `get` 找不到资源时会直接报错并终止程序。
