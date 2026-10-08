// Gridstack.js ist installiert, das CSS wird in main.js geladen.
// In einer Komponente das Raster erst nach dem Mounten anlegen und beim
// Verlassen wieder entfernen:
//
//   import { onMounted, onBeforeUnmount, useTemplateRef } from 'vue'
//   import { GridStack } from '@/lib/gridstack'
//
//   const gridEl = useTemplateRef('grid')
//   let grid
//   onMounted(() => { grid = GridStack.init({ column: 12, cellHeight: 60 }, gridEl.value) })
//   onBeforeUnmount(() => grid?.destroy(false))
//
//   <div ref="grid" class="grid-stack"></div>
//
// Doku: https://gridstackjs.com

export { GridStack } from 'gridstack'
