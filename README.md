# Pulumi 架构师之路：交互式教程

基于 VitePress + Killercoda 的中文 Pulumi 交互式电子书。前端教程部署到 GitHub Pages，动手实验由 Killercoda 提供云端终端环境。

## 本地开发

```bash
npm install
npm run dev
```

## 构建与预览

```bash
npm run build
npm run preview
```

推送到 `main` 分支后，可通过 GitHub Actions 自动构建并部署到 GitHub Pages。

## 项目结构

```text
docs/                          # VitePress 内容（Markdown 教程章节）
	.vitepress/
		config.mjs                 # VitePress 配置（侧边栏自动管理）
		components/
			KillercodaEmbed.vue      # Killercoda 实验入口组件
		theme/
			index.js                 # 注册全局组件
pulumi-tutorial/               # Killercoda 场景定义
	structure.json               # 场景列表
	pulumi-get-started/          # 每个场景一个目录
	pulumi-projects-stacks-state/
	pulumi-resources-options/
	pulumi-inputs-outputs-secrets/
	pulumi-components/
	pulumi-automation-api/
	pulumi-automation-api-azure/
	pulumi-policy-as-code-aws/
	pulumi-policy-as-code-azure/
	pulumi-testing-cicd/
scripts/
	setup-common.sh              # Killercoda 共享环境初始化脚本
	sync-setup-common.mjs        # 将共享脚本复制到各场景 assets/
	sync-sidebar.mjs             # 从 docs/*.md frontmatter 自动生成侧边栏
```

## Killercoda 场景

场景定义位于 `pulumi-tutorial/` 目录。将本仓库关联到 Killercoda Creator 账号后，在 Killercoda 控制台同步课程内容即可。

当前页面中的 Killercoda 链接使用占位账号 `pulumi-tutorial`，发布前请把 `docs/*.md` 中的链接替换为真实 Killercoda Creator slug。

## 写作方式

1. 每章正文写在 `docs/*.md`，通过 frontmatter 的 `order`、`title`、`group` 参与侧边栏生成。
2. 每章实验写在 `pulumi-tutorial/<scenario>/`，由对应章节通过 `<KillercodaEmbed />` 链接。
3. 新增章节后运行 `npm run sync-sidebar`。
4. 新增实验后运行 `npm run sync-killercoda`。
