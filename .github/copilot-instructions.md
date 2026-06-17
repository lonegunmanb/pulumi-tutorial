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

## Writing style

- Explain Pulumi concepts through architecture diagrams, short examples, production pitfalls, and checklists.
- Keep code examples runnable in Killercoda whenever possible.
- Map each chapter back to the relevant Pulumi official documentation path.

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