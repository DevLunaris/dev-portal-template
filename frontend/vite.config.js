import { fileURLToPath, URL } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig, loadEnv } from 'vite'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // Werte aus frontend/.env, frontend/.env.local usw. und aus der Umgebung
  // (in der VM setzt docker/compose.yaml sie). Ohne Angaben gelten die
  // Standardwerte für lokale Entwicklung.
  const env = loadEnv(mode, process.cwd(), '')

  // Wohin der Dev-Server /api weiterleitet (CodeIgniter). Standard: php spark serve.
  // Mit Laragon z. B. DEV_API_TARGET=http://projektname.test in frontend/.env.local
  const apiTarget = env.DEV_API_TARGET || 'http://localhost:8080'

  // Zusätzlich erlaubte Hostnamen, z. B. die Adresse hinter Pangolin
  const allowedHosts = (env.DEV_ALLOWED_HOSTS || '')
    .split(',')
    .map((host) => host.trim())
    .filter(Boolean)

  // Port, über den der Browser den HMR-Websocket erreicht. Leer = derselbe Port
  // wie die Seite (443 hinter Pangolin, 8000 im LAN, 5173 lokal).
  const hmrClientPort = Number(env.DEV_HMR_CLIENT_PORT) || undefined

  return {
    // Unterpfad des Dev-Servers, in der VM /preview/ (Dev-Portal)
    base: env.DEV_BASE || '/',
    plugins: [vue()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
    server: {
      allowedHosts,
      hmr: hmrClientPort ? { clientPort: hmrClientPort } : true,
      proxy: {
        '/api': {
          target: apiTarget,
          changeOrigin: true,
        },
      },
    },
  }
})
