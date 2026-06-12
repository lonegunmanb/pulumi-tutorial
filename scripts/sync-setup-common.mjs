import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const source = path.join(root, 'scripts', 'setup-common.sh')
const scenariosDir = path.join(root, 'pulumi-tutorial')

if (!fs.existsSync(source)) {
  throw new Error(`Missing ${source}`)
}

const scenarioNames = fs
  .readdirSync(scenariosDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .filter((name) => fs.existsSync(path.join(scenariosDir, name, 'index.json')))

for (const name of scenarioNames) {
  const assetsDir = path.join(scenariosDir, name, 'assets')
  fs.mkdirSync(assetsDir, { recursive: true })
  fs.copyFileSync(source, path.join(assetsDir, 'setup-common.sh'))
}

console.log(`Synced setup-common.sh to ${scenarioNames.length} scenarios.`)