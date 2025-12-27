import axios from 'axios'
import { ElMessage } from 'element-plus'
import Cookies from 'js-cookie'

const api = axios.create({
  baseURL: '/api',
  timeout: 5000
})

// 请求拦截器
api.interceptors.request.use(
  config => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  error => {
    return Promise.reject(error)
  }
)

// 响应拦截器
api.interceptors.response.use(
  response => {
    return response
  },
  error => {
    if (error.response) {
      if (error.response.status === 401 || error.response.status === 422) {
        // 清除认证信息
        localStorage.removeItem('token')
        localStorage.removeItem('user')
        Cookies.remove('access_token_cookie')

        // 如果不在登录页，才跳转
        if (!window.location.pathname.startsWith('/login')) {
          window.location.href = '/login'
        }
        return Promise.reject(error)
      }
      ElMessage.error(error.response.data.message || '请求失败')
    } else {
      ElMessage.error('网络错误')
    }
    return Promise.reject(error)
  }
)

export default api
