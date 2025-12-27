<template>
  <div class="navbar">
    <div class="logo" @click="$router.push('/teams')">
      CollabU
    </div>
    
    <div class="right-menu">
      <NotificationCenter />
      
      <el-dropdown trigger="click" @command="handleCommand">
        <div class="user-info">
          <el-avatar :size="32" class="user-avatar">
            {{ userStore.user?.nickname || userStore.user?.username?.charAt(0).toUpperCase() }}
          </el-avatar>
          <span class="username">{{ userStore.user?.nickname || userStore.user?.username }}</span>
          <el-icon class="el-icon--right"><arrow-down /></el-icon>
        </div>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item command="profile">个人资料</el-dropdown-item>
            <el-dropdown-item divided command="logout">退出登录</el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </div>
</template>

<script setup>
import { useUserStore } from '../stores/user'
import { useRouter } from 'vue-router'
import { ArrowDown } from '@element-plus/icons-vue'
import NotificationCenter from './NotificationCenter.vue'

const userStore = useUserStore()
const router = useRouter()

const handleCommand = (command) => {
  if (command === 'profile') {
    router.push('/profile')
  } else if (command === 'logout') {
    userStore.logout()
    router.push('/login')
  }
}
</script>

<style scoped>
.navbar {
  height: 60px;
  background: white;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 20px;
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 1000;
}

.logo {
  font-size: 20px;
  font-weight: bold;
  color: #409eff;
  cursor: pointer;
}

.right-menu {
  display: flex;
  align-items: center;
  gap: 20px;
}

.user-info {
  display: flex;
  align-items: center;
  cursor: pointer;
  padding: 5px;
  border-radius: 4px;
}
.user-info:hover {
  background: #f5f5f5;
}

.username {
  margin-left: 8px;
  font-size: 14px;
  color: #333;
}

.user-avatar {
  background: #409eff;
}
</style>
