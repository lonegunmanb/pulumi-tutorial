# Copilot instructions for this repository

This repository is a Chinese interactive Pulumi tutorial built with VitePress and Killercoda.

## Content layout

- Write book chapters in `docs/*.md`.
- Every chapter page except `docs/index.md` must have frontmatter with `order`, `title`, and `group`.
- Do not edit the generated sidebar block in `docs/.vitepress/config.mjs` manually; run `npm run sync-sidebar`.

## Killercoda layout

- Put Killercoda scenarios under `pulumi-tutorial/<scenario>/`.
- Keep each scenario self-contained with `index.json`, `init/`, `step*/`, and `finish/`.
- Use `scripts/setup-common.sh` as the single source for shared lab setup, then run `npm run sync-killercoda`.
- Prefer local or simulated resources in labs. Avoid requiring real cloud credentials unless a chapter explicitly explains credential setup.
- When a lab needs a cloud provider example, use `pulumi/pulumi-aws` for AWS examples and `pulumi/pulumi-azure` for Azure examples. Keep this provider choice consistent across all new hands-on labs.
- Put environment-preparation code in `init/background.sh`, not in `step*/`. This includes starting the simulated public-cloud environment (`ministack` for AWS, `miniblue` for Azure) via `docker compose up -d` and waiting for its health check to pass. By the time a learner reaches step 1, the simulator should already be up; steps should only contain the lab's teaching commands (e.g. `pulumi up`).

## Writing style

- Explain Pulumi concepts through architecture diagrams, short examples, production pitfalls, and checklists.
- Keep code examples runnable in Killercoda whenever possible.
- Map each chapter back to the relevant Pulumi official documentation path.
- 文章要浅显易懂，读者默认是初学者：多用类比、循序渐进、把抽象概念讲清楚。但措辞要**书面化**，避免过于口语化的网络用语或俚语（例如「立靶子」「钉死」「省事」「兜底」「一口气走一遍」等），改用对应的书面表达。

## 基于官方文档撰写后的事实核查

当本次撰写/改写的内容是**参考官方文档**完成的（例如用户给了一个或多个官方文档链接作为依据），正文写完后**必须**走一遍事实核查流程：

- **启动独立子 agent 核查**：写完后启动一个独立的子 agent（subagent），把本次撰写的内容与所引用的官方文档逐条对比，检查两件事：
  - **对不对**：有没有与官方文档相悖、过时或臆造的说法（命令、参数、行为、限制等）。
  - **全不全**：官方文档里与本章主题密切相关的重要点，有没有遗漏。
  - 子 agent 应在反馈中明确指出每条问题对应的官方文档出处，便于复核。
- **批判性对待子 agent 的反馈**：禁止无脑照单全收。要逐条独立思考、对照官方文档原文判断子 agent 的意见是否成立。
  - **认同的**：照子 agent 的意见修改正文。
  - **不认同的**：允许与子 agent 进行辩论，往返**至多 10 轮**，用官方文档原文作为裁决依据。
  - **僵持的**：如果 10 轮辩论仍无法达成一致，则把**分歧意见**（双方各自的主张与依据）写在文章最前面（frontmatter 之后、正文之前）的一个醒目区块里，标注「待人类裁决」，交由人类裁决，不要擅自定稿删除分歧。

## 插图占位与绘图提示词

当某个概念或流程过于抽象、复杂时，用「图画占位 + 引用 + 绘图提示词」的方式帮助读者理解：

- 在 `docs/images/` 下放一张 1x1 的 PNG 占位文件（placeholder），命名用 `<topic>-<concept>.png` 形式，例如 `stacks-state-import-ledger.png`。可用 PowerShell 写入 1 像素透明 PNG：
  ```powershell
  $b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAen63NgAAAAASUVORK5CYII='
  [IO.File]::WriteAllBytes('docs/images/<topic>-<concept>.png', [Convert]::FromBase64String($b64))
  ```
- 在正文相应位置插入图片引用：`![中文 alt 文本](./images/<topic>-<concept>.png)`。
- 紧跟在图片下方用 blockquote 写「绘图提示词」，描述画面内容，便于后续替换成真正的插画：
  ```markdown
  ![State import 像更换一本资产登记簿](./images/stacks-state-import-ledger.png)

  > 绘图提示词：……
  ```
- 绘图提示词的固定风格：淡水彩阴影漫画插画风格（light watercolor shaded comic illustration），青色（cyan）主色调，拟物质感，用真实实物打比方引导读者理解复杂概念；提示词中 professional / technical terms 用英语，其余用中文。
- 绘图提示词里如果出现代表 Pulumi 的角色，必须用 Pulumi 的吉祥物——一只鸭嘴兽（the Pulumi mascot platypus）的形象来表现，不要用其他拟人形象代替。鸭嘴兽青色身体，嘴巴颜色是 #F361D6，圆圆的眼睛，短短的四肢，憨态可掬的样子。可以参考 Pulumi 官网和文档里吉祥物的各种形象来描绘。