# 结构化配置：--path 与 requireObject

配置不只能存简单字符串，还能存对象、数组、嵌套结构。用 `--path` 标志把值写进对象的指定位置：

```bash
pulumi config set --path 'tags.team' platform
```{{exec}}

```bash
pulumi config set --path 'tags.env' dev
```{{exec}}

```bash
pulumi config set --path 'tags.replicas' 3
```{{exec}}

看它在配置文件里组装成了一个嵌套对象：

```bash
cat Pulumi.dev.yaml
```{{exec}}

注意 `replicas` 被存成了**整数 3**，而不是字符串 "3"——对结构化配置，能转成整数的值会按整数持久化，`true` / `false` 会按布尔值持久化。

切换到读取结构化配置的程序：

```bash
cp variants/step3.ts index.ts && cat index.ts
```{{exec}}

程序里用 `requireObject<Tags>("tags")` 一次读出整个对象。这里有个常见陷阱：它返回的是一个普通对象，不是 Config 实例，所以取嵌套值要用标准的属性访问（形如 tags.team），不能再像 Config 那样链式调用 require。

部署，再看桶上的标签：

```bash
pulumi up --yes && pulumi stack output tagsFromConfig
```{{exec}}
