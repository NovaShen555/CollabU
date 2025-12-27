import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    name: 'Home',
    redirect: () => {
      const token = localStorage.getItem('token')
      return token ? '/teams' : '/login'
    }
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/Login.vue')
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('../views/Register.vue')
  },
  {
    path: '/teams',
    name: 'Teams',
    component: () => import('../views/Teams.vue')
  },
  {
    path: '/teams/:teamId',
    name: 'TeamDetails',
    component: () => import('../views/TeamDetails.vue')
  },
  {
    path: '/projects/:projectId',
    name: 'ProjectDetails',
    component: () => import('../views/ProjectDetails.vue')
  },
  {
    path: '/profile',
    name: 'Profile',
    component: () => import('../views/Profile.vue')
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
