<script setup>
import { onMounted, ref } from 'vue'
import { api } from '@/lib/api'

const health = ref(null)
const error = ref(null)
const loading = ref(true)

async function check() {
  loading.value = true
  error.value = null
  try {
    health.value = await api.get('/health')
  } catch (e) {
    health.value = e.data ?? null
    error.value = e.message
  } finally {
    loading.value = false
  }
}

onMounted(check)
</script>

<template>
  <main>
    <h1>Meine App</h1>

    <p v-if="loading">Prüfe Verbindung …</p>
    <template v-else>
      <p>
        API: <strong>{{ health ? 'erreichbar' : 'nicht erreichbar' }}</strong>
      </p>
      <p>
        Datenbank:
        <strong>{{ health?.database?.connected ? 'erreichbar' : 'nicht erreichbar' }}</strong>
        <span v-if="health?.database?.connected">
          ({{ health.database.name }}, MySQL {{ health.database.version }})
        </span>
      </p>
      <p v-if="health">Umgebung: {{ health.environment }}</p>
      <p v-if="error">Fehler: {{ health?.database?.error || error }}</p>
    </template>

    <button type="button" @click="check">Erneut prüfen</button>
  </main>
</template>

<style scoped>
main {
  font-family: system-ui, sans-serif;
  max-width: 40rem;
  margin: 2rem auto;
  padding: 0 1rem;
}
</style>
