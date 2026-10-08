// Kleiner Helfer für Aufrufe an die CodeIgniter-API unter /api.
// Frontend und API laufen immer unter demselben Origin, daher kein CORS.
//
//   import { api } from '@/lib/api'
//   const health = await api.get('/health')
//   await api.post('/irgendwas', { feld: 'wert' })

export class ApiError extends Error {
  constructor(message, status, data) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.data = data
  }
}

export async function apiFetch(path, { method = 'GET', body, headers = {}, ...options } = {}) {
  const init = {
    method,
    headers: { Accept: 'application/json', ...headers },
    credentials: 'same-origin',
    ...options,
  }

  if (body !== undefined) {
    if (body instanceof FormData) {
      init.body = body
    } else {
      init.headers['Content-Type'] = 'application/json'
      init.body = JSON.stringify(body)
    }
  }

  const response = await fetch(`/api${path}`, init)
  const isJson = response.headers.get('Content-Type')?.includes('application/json')
  const data = isJson ? await response.json() : await response.text()

  if (!response.ok) {
    const message = (isJson && (data.message || data.messages?.error)) || response.statusText
    throw new ApiError(message, response.status, data)
  }

  return data
}

export const api = {
  get: (path, options) => apiFetch(path, options),
  post: (path, body, options) => apiFetch(path, { ...options, method: 'POST', body }),
  put: (path, body, options) => apiFetch(path, { ...options, method: 'PUT', body }),
  patch: (path, body, options) => apiFetch(path, { ...options, method: 'PATCH', body }),
  delete: (path, options) => apiFetch(path, { ...options, method: 'DELETE' }),
}
