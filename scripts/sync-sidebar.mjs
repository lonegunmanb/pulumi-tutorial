import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const docsDir = path.join(root, 'docs')
const configPath = path.join(docsDir, '.vitepress', 'config.mjs')

function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/)
  if (!match) return {}

  return Object.fromEntries(
    match[1]
      .split(/\r?\n/)
      .map((line) => line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/))
      .filter(Boolean)
      .map(([, key, raw]) => [key, raw.replace(/^['"]|['"]$/g, '').trim()])
  )
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function toJsString(value) {
  return JSON.stringify(value)
}

const pages = fs
  .readdirSync(docsDir)
  .filter((name) => name.endsWith('.md') && name !== 'index.md')
  .map((name) => {
    const filePath = path.join(docsDir, name)
    const content = fs.readFileSync(filePath, 'utf8')
    const fm = parseFrontmatter(content)
    return {
      name,
      order: Number.parseInt(fm.order ?? '9999', 10),
      title: fm.title ?? name.replace(/\.md$/, ''),
      group: fm.group ?? '教程章节',
      link: `/${name.replace(/\.md$/, '')}`,
    }
  })
  .sort((a, b) => a.order - b.order || a.name.localeCompare(b.name))

const groups = new Map()
for (const page of pages) {
  if (!groups.has(page.group)) {
    groups.set(page.group, [])
  }
  groups.get(page.group).push(page)
}

const groupItems = [...groups.entries()]
  .map(([group, items]) => {
    const children = items
      .map((item) => `              { text: ${toJsString(item.title)}, link: ${toJsString(item.link)} }`)
      .join(',\n')

    return `          {\n            text: ${toJsString(group)},\n            collapsed: false,\n            items: [\n${children}\n            ]\n          }`
  })
  .join(',\n')

const sidebar = `sidebar: [\n      {\n        text: '教程章节',\n        items: [\n${groupItems}\n        ],\n      },\n    ],`

const start = '// @auto-sidebar-start'
const end = '// @auto-sidebar-end'
const config = fs.readFileSync(configPath, 'utf8')
const markerPattern = new RegExp(`${escapeRegExp(start)}[\\s\\S]*?${escapeRegExp(end)}`)

if (!markerPattern.test(config)) {
  throw new Error(`Cannot find sidebar markers in ${configPath}`)
}

const nextConfig = config.replace(markerPattern, `${start}\n    ${sidebar.replace(/\n/g, '\n    ')}\n    ${end}`)
fs.writeFileSync(configPath, nextConfig)
console.log(`Synced sidebar for ${pages.length} pages.`)