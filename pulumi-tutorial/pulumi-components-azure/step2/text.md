# 封装成 ComponentResource

把刚才那段平铺代码切换成「组件版」：

```bash
cd /root/workspace && cp variants/component.ts index.ts && cat index.ts
```{{exec}}

对照看这份 `index.ts`，注意四个固定动作：

- **定义入参**：用一个 interface 描述 team 等可配置项，每个标量都用 `pulumi.Input<T>` 包起来。
- **继承基类**：让组件类继承 ComponentResource，构造函数里调用 super(...) 注册类型名 `acme:index:SecureStorage`。
- **创建子资源**：资源组和两个存储账户都用实例名拼前缀，并都把 `parent` 指向组件自身。
- **注册输出**：结尾调用 `registerOutputs(...)` 把输出存进 state。

另外注意实例化那一行：provider 是通过 `providers: [miniblue]`（复数）传给组件的，下一步细讲。

部署组件版：

```bash
pulumi up --yes
```{{exec}}

留意 CLI 输出现在是一棵**树**：`acme:index:SecureStorage` 组件下面，嵌套着它创建的资源组和两个存储账户。再用 state 确认父子关系：

```bash
pulumi stack export | jq -r '.deployment.resources[] | [.type, (.urn | split("::") | last), (.parent // "—" | split("::") | last)] | @tsv'
```{{exec}}

这次两个存储账户（连同那个资源组）的 `parent` 不再是 Stack，而是 `media` 这个组件实例。子资源的 URN 里也带上了组件的类型与名字——父子关系被真正建立了起来。

最后看组件注册的输出：

```bash
pulumi stack output
```{{exec}}

`accountName` 和 `logsAccountName` 来自组件内部 `registerOutputs()` 注册、再经类属性暴露的值。使用者读组件的输出，和读普通资源的输出没有任何区别。
