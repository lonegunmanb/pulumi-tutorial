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