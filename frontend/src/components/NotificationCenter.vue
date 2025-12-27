<template>
  <el-popover
    placement="bottom"
    :width="300"
    trigger="click"
  >
    <template #reference>
      <el-badge :value="unreadCount" :hidden="unreadCount === 0" class="notification-badge">
        <el-button circle icon="Bell" />
      </el-badge>
    </template>
    
    <div class="notification-list">
      <div class="header">
        <span>通知</span>
        <el-button type="primary" link size="small" @click="markAllRead">全部已读</el-button>
      </div>
      
      <div v-if="notifications.length === 0" class="empty">
        <el-empty description="暂无通知" :image-size="40" />
      </div>
      
      <div v-else class="list-content">
        <div v-for="notif in notifications" :key="notif.id" class="notif-item" :class="{ unread: !notif.is_read }" @click="handleRead(notif)">
          <div class="notif-content">{{ notif.content }}</div>
          <div class="notif-time">{{ formatTime(notif.created_at) }}</div>
        </div>
      </div>
    </div>
  </el-popover>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { Bell } from '@element-plus/icons-vue'
import api from '../api'

const notifications = ref([])

const unreadCount = computed(() => {
  return notifications.value.filter(n => !n.is_read).length
})

const fetchNotifications = async () => {
  try {
    const res = await api.get('/notifications')
    notifications.value = res.data
  } catch (error) {
    console.error(error)
  }
}

const markAllRead = async () => {
  try {
    await api.put('/notifications/read-all')
    notifications.value.forEach(n => n.is_read = true)
  } catch (error) {
    console.error(error)
  }
}

const handleRead = async (notif) => {
  if (notif.is_read) return
  try {
    await api.put(`/notifications/${notif.id}/read`)
    notif.is_read = true
  } catch (error) {
    console.error(error)
  }
}

const formatTime = (iso) => {
  return new Date(iso).toLocaleString()
}

onMounted(() => {
  fetchNotifications()
  // Poll for notifications every minute
  setInterval(fetchNotifications, 60000)
})
</script>

<style scoped>
.notification-badge {
  margin-right: 15px;
}
.notification-list .header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-bottom: 10px;
  border-bottom: 1px solid #eee;
}
.list-content {
  max-height: 300px;
  overflow-y: auto;
}
.notif-item {
  padding: 10px 0;
  border-bottom: 1px solid #f5f5f5;
  cursor: pointer;
}
.notif-item:hover {
  background-color: #f9f9f9;
}
.notif-item.unread {
  font-weight: bold;
}
.notif-item.unread::before {
  content: '•';
  color: red;
  margin-right: 5px;
}
.notif-time {
  font-size: 12px;
  color: #999;
  margin-top: 5px;
  font-weight: normal;
}
</style>
