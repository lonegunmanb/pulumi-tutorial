import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const scenariosDir = path.join(root, 'pulumi-tutorial')
const structurePath = path.join(scenariosDir, 'structure.json')

const preferredOrder = [
  'pulumi-architecture-aws',
  'pulumi-architecture-azure',
  'pulumi-how-pulumi-works-aws',
  'pulumi-how-pulumi-works-azure',
  'pulumi-get-started',
  'pulumi-projects-stacks-state',
  'pulumi-projects-stacks-state-azure',
  'pulumi-stacks-azure',
  'pulumi-state-backends-aws',
  'pulumi-state-backends-azure',
  'pulumi-resources-options',
  'pulumi-resources-options-azure',
  'pulumi-providers',
  'pulumi-inputs-outputs',
  'pulumi-inputs-outputs-azure',
  'pulumi-inputs-outputs-secrets',
  'pulumi-secrets-handling',
  'pulumi-stash',
  'pulumi-functions',
  'pulumi-assets-archives',
  'pulumi-components',
  'pulumi-components-azure',
  'pulumi-config',
  'pulumi-dynamic-stacks-aws',
  'pulumi-dynamic-stacks-azure',
  'pulumi-automation-api',
  'pulumi-automation-api-azure',
  'pulumi-policy-as-code-aws',
  'pulumi-policy-as-code-azure',
  'pulumi-debugging-aws',
  'pulumi-debugging-azure',
  'pulumi-testing-cicd',
  'pulumi-testing-cicd-azure',
  'pulumi-best-practices-aws',
  'pulumi-best-practices-azure',
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