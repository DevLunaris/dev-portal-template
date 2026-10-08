import { createRouter, createWebHistory } from 'vue-router'
import StartView from '@/views/StartView.vue'

const router = createRouter({
  // BASE_URL ist "/" bzw. im Dev-Portal "/preview/" (siehe vite.config.js)
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', name: 'start', component: StartView },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('@/views/NotFoundView.vue'),
    },
  ],
})

export default router
