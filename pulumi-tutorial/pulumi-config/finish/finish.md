# 完成

你已经走通了 Pulumi 配置系统的完整闭环：

- 用 `pulumi config set` / get 存取配置，看懂了 Stack 配置文件与命名空间（aws:region 与项目级键的区别）。
- 在程序里用 Config 对象的 require / get 及类型化 getter 读取配置，并用它驱动资源的数量与属性。
- 用 `--path` 设置结构化配置（对象 / 数组 / 嵌套），再用 requireObject 读取，并理解了「返回普通对象、不能链式 require」的陷阱。
- 用 `--secret` 设置机密配置，看到它在 YAML 里以密文存储、在输出里被遮蔽成 [secret]。
- 用项目级默认值与 Stack 级覆盖，让同一套程序在 dev 与 prod 上产出不同规模的基础设施。
- 用 `new pulumi.Config("app")` 让组件从自己的命名空间读配置，与项目级同名键在同一份配置文件里并存不冲突。

## 清理

销毁 TypeScript 项目（dev）与 Go 项目（dev / prod）的资源并停掉 MiniStack：

```bash
cd /root/workspace && pulumi destroy --yes --stack dev ; \
cd /root/workspace-go && pulumi destroy --yes --stack dev ; \
pulumi destroy --yes --stack prod ; \
cd /root/workspace && docker compose down
```{{exec}}

## 延伸阅读

- 教程正文：Configuration 配置一章。
- 官方文档：<https://www.pulumi.com/docs/iac/concepts/config/>
- 机密配置的完整机制：Secrets 机密处理一章。
- 以编程方式写配置 / 动态创建 Stack：Automation API 一章。
