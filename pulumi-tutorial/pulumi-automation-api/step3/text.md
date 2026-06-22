# 执行更新并读取输出

现在让 Automation API 执行更新。程序会输出引擎日志、资源事件和最终 JSON 结果。

```bash
cd /root/workspace && \
npx ts-node --transpile-only automation.ts up dev && \
npx ts-node --transpile-only automation.ts outputs dev && \
npx ts-node --transpile-only automation.ts refresh dev
```{{exec}}

outputs 动作读取 Stack 输出，并把 secret 输出显示为占位值。refresh 动作用来同步状态，实验中没有制造漂移，所以结果应当很小。