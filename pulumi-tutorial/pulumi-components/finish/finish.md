# 完成

你已经走完了组件化的完整路径：

- 从**平铺**资源出发，看到散装资源在 state 里没有层级。
- 把它封装成 `SecureBucket` 组件，掌握写组件的四个固定动作：定义入参、继承基类调用 super、创建带 parent 的子资源、最后 registerOutputs 收尾。
- 观察了父子 URN、树状的 `pulumi up` 输出，以及组件输出如何进入 stack output。
- 复用组件两次，验证子资源名靠 `${name}` 前缀避免撞 URN，并理解 providers（复数）如何把 provider 配置下传给子资源。
- 演进组件：明白「加东西安全、改子资源名会触发重建」，并用 `aliases` 完成零重建改名。

清理环境（可选）：

```bash
cd /root/workspace && pulumi destroy --yes && docker compose down
```{{exec}}

想用同一组概念体验 Azure 版（用 `@pulumi/azure` 对接 miniblue，把一组 Resource Group 封装成 `LandingZone` 组件），可以去配套的 Azure 实验。回到正文继续阅读《企业级架构：Components》的演进与发布部分。
