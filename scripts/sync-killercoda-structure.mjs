import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const scenariosDir = path.join(root, 'pulumi-tutorial')
const structurePath = path.join(scenariosDir, 'structure.json')

const preferredOrder = [
  'pulumi-architecture-aws',
  'pulumi-architecture-azure',
  'pulumi-get-started',
  'pulumi-projects-stacks-state',
  'pulumi-projects-stacks-state-azure',
  'pulumi-resources-options',
  'pulumi-inputs-outputs-secrets',
  'pulumi-components',
  'pulumi-automation-api',
  'pulumi-packages-crossguard',
  'pulumi-testing-cicd',
]

const existing = fs
  .readdirSync(scenariosDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .filter((name) => fs.existsSync(path.join(scenariosDir, name, 'index.json')))

const ordered = [
  ...preferredOrder.filter((name) => existing.includes(name)),
  ...existing.filter((name) => !preferredOrder.includes(name)).sort(),
]

fs.writeFileSync(structurePath, `${JSON.stringify({ items: ordered.map((scenario) => ({ path: scenario })) }, null, 2)}\n`)
console.log(`Synced Killercoda structure for ${ordered.length} scenarios.`)