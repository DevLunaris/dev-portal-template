// Übernimmt die Standardeinstellungen aus dem Image in die Benutzer-
// einstellungen von code-server. Nur fehlende Schlüssel werden ergänzt,
// eigene Änderungen bleiben erhalten.
const fs = require('node:fs')
const path = require('node:path')

const [defaultsFile, userFile] = process.argv.slice(2)
const defaults = JSON.parse(fs.readFileSync(defaultsFile, 'utf8'))

let user = {}
if (fs.existsSync(userFile)) {
  try {
    user = JSON.parse(fs.readFileSync(userFile, 'utf8') || '{}')
  } catch {
    console.log(`${userFile} enthält Kommentare o. Ä., Standardeinstellungen werden nicht ergänzt`)
    process.exit(0)
  }
}

const missing = Object.keys(defaults).filter((key) => !(key in user))
if (missing.length === 0) process.exit(0)

for (const key of missing) user[key] = defaults[key]
fs.mkdirSync(path.dirname(userFile), { recursive: true })
fs.writeFileSync(userFile, JSON.stringify(user, null, 2) + '\n')
console.log(`Einstellungen ergänzt: ${missing.join(', ')}`)
