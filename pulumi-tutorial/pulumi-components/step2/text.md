# 改造成组件

尝试新增一个继承 `pulumi.ComponentResource` 的类，把 `RandomPet` 封装到组件内部，并在构造函数末尾调用 `this.registerOutputs()`。

完成后运行：

```bash
pulumi preview
```{{exec}}

观察父子 URN 如何变化。