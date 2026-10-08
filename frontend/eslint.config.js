import js from '@eslint/js'
import prettier from 'eslint-config-prettier/flat'
import pluginVue from 'eslint-plugin-vue'
import { defineConfig, globalIgnores } from 'eslint/config'
import globals from 'globals'

// ESLint prüft den Code auf Fehler, Prettier übernimmt die Formatierung.
// eslint-config-prettier schaltet alle Regeln ab, die sich mit Prettier beißen.
export default defineConfig([
  globalIgnores(['dist/**']),
  {
    files: ['**/*.{js,mjs,vue}'],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['*.config.js'],
    languageOptions: { globals: globals.node },
  },
  js.configs.recommended,
  ...pluginVue.configs['flat/recommended'],
  prettier,
])
