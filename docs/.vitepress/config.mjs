import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Pulumi 架构师之路',
  description: '基于 Killercoda 的中文 Pulumi 交互式教程',
  base: '/pulumi-tutorial/',
  lang: 'zh-CN',
  cleanUrls: true,
  sitemap: {
    hostname: 'https://your-org.github.io/pulumi-tutorial/'
  },

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">🏗️</text></svg>' }],
  ],

  themeConfig: {
    logo: { text: '🏗️' },
    nav: [
      { text: '首页', link: '/' },
      { text: '开始学习', link: '/intro' },
      { text: 'GitHub', link: 'https://github.com/your-org/pulumi-tutorial' },
    ],

    // @auto-sidebar-start
    sidebar: [
          {
            text: '教程章节',
            items: [
              {
                text: "起步",
                collapsed: false,
                items: [
                  { text: "课程介绍", link: "/intro" }
                ]
              },
              {
                text: "第 1 篇：Get Started & 架构基石",
                collapsed: false,
                items: [
                  { text: "IaC 范式转移与 Pulumi 架构解析", link: "/architecture" },
                  { text: "项目、堆栈与状态管理", link: "/projects-stacks-state" }
                ]
              },
              {
                text: "第 2 篇：Concepts 深度剖析",
                collapsed: false,
                items: [
                  { text: "资源与精细控制", link: "/resources" },
                  { text: "Inputs, Outputs & Secrets", link: "/inputs-outputs-secrets" },
                  { text: "企业级架构：Components", link: "/components" }
                ]
              },
              {
                text: "第 3 篇：Automation API, Packages & Guides",
                collapsed: false,
                items: [
                  { text: "Automation API", link: "/automation-api" },
                  { text: "Packages 与 CrossGuard", link: "/packages-crossguard" },
                  { text: "测试驱动开发与 CI/CD 实践", link: "/testing-cicd" }
                ]
              },
              {
                text: "附录",
                collapsed: false,
                items: [
                  { text: "附录与速查表", link: "/appendix" }
                ]
              }
            ],
          },
        ],
    // @auto-sidebar-end

    socialLinks: [
      { icon: 'github', link: 'https://github.com/your-org/pulumi-tutorial' },
    ],

    search: {
      provider: 'local'
    },

    footer: {
      message: 'Pulumi 架构师之路：交互式教程',
      copyright: 'Copyright © 2026'
    }
  },

  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark'
    }
  }
})