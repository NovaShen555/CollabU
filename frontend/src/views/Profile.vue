<template>
  <div class="profile-container">
    <el-card class="profile-card">
      <template #header>
        <h2>个人资料</h2>
      </template>
      <div class="profile-content">
        <div class="avatar-section">
           <el-avatar :size="100" class="profile-avatar">
             {{ user.nickname || user.username?.charAt(0).toUpperCase() }}
           </el-avatar>
        </div>
        
        <el-form :model="user" label-width="80px" class="info-form">
           <el-form-item label="用户名">
             <el-input v-model="user.username" disabled />
           </el-form-item>
           <el-form-item label="昵称">
             <el-input v-model="user.nickname" placeholder="请输入昵称" />
           </el-form-item>
           <el-form-item label="邮箱">
             <el-input v-model="user.email" disabled />
           </el-form-item>
           <el-form-item label="学号">
             <el-input v-model="user.student_id" disabled />
           </el-form-item>
        </el-form>
      </div>

      <el-divider />

      <h3>保存修改</h3>
      <el-button type="primary" @click="updateProfile">保存基本信息</el-button>

      <el-divider />
      
      <h3>修改密码</h3>
      <el-form :model="passwordForm" label-width="100px" style="max-width: 400px">
        <el-form-item label="旧密码">
          <el-input v-model="passwordForm.old_password" type="password" show-password />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="passwordForm.new_password" type="password" show-password />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="changePassword">确认修改</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import api from '../api'
import { useUserStore } from '../stores/user'
import { ElMessage } from 'element-plus'

const userStore = useUserStore()
const user = ref({})
const passwordForm = reactive({
  old_password: '',
  new_password: ''
})

const fetchProfile = async () => {
  try {
    const res = await api.get('/auth/me')
    user.value = res.data
    // Update store
    userStore.setUser(res.data)
  } catch (error) {
    console.error(error)
  }
}

const updateProfile = async () => {
  try {
    await api.put('/auth/profile', {
      nickname: user.value.nickname
    })
    ElMessage.success('信息保存成功')
    // Update store
    userStore.setUser({ ...userStore.user, ...user.value })
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

const changePassword = async () => {
  if (!passwordForm.old_password || !passwordForm.new_password) {
    ElMessage.warning('请填写密码')
    return
  }
  
  try {
    await api.put('/auth/password', passwordForm)
    ElMessage.success('密码修改成功')
    passwordForm.old_password = ''
    passwordForm.new_password = ''
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '修改失败')
  }
}

onMounted(() => {
  fetchProfile()
})
</script>

<style scoped>
.profile-container {
  padding: 20px;
  max-width: 800px;
  margin: 0 auto;
}
.profile-content {
  display: flex;
  gap: 40px;
  margin-bottom: 30px;
}
.avatar-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 15px;
}
.info-form {
  flex: 1;
  max-width: 400px;
}
</style>
