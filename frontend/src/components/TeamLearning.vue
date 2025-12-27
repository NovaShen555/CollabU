<template>
  <div class="team-learning-container">
    <div class="input-section">
      <el-card shadow="never">
        <template #header>
          <div class="card-header">
            <span>我的学习进度</span>
          </div>
        </template>
        <div class="input-content">
          <el-input
            v-model="myContent"
            type="textarea"
            :rows="3"
            placeholder="今天学了什么？分享一下你的进度..."
            resize="none"
          />
          <div class="actions">
            <div></div> <!-- Spacer -->
            <el-button type="primary" @click="submitProgress" :loading="submitting">发布更新</el-button>
          </div>
        </div>
      </el-card>
    </div>

    <div class="feed-section">
      <h3>组员动态</h3>
      <div v-if="loading" class="loading">
        <el-skeleton :rows="3" animated count="3" />
      </div>
      <div v-else class="feed-list">
        <el-table :data="tableData" style="width: 100%" border class="progress-table">
          <el-table-column label="成员" width="150" fixed>
            <template #default="scope">
              <div class="user-info">
                <el-avatar :src="scope.row.avatar" :size="32">
                  {{ scope.row.name ? scope.row.name.charAt(0).toUpperCase() : 'U' }}
                </el-avatar>
                <span class="username">{{ scope.row.name }}</span>
              </div>
            </template>
          </el-table-column>
          
          <el-table-column 
            v-for="date in dateColumns" 
            :key="date.key" 
            :label="date.label" 
            min-width="200"
          >
            <template #default="scope">
              <div class="day-content" v-if="scope.row.data[date.key]">
                <div 
                  v-for="(item, idx) in scope.row.data[date.key]" 
                  :key="idx" 
                  class="progress-item"
                  :class="{ 'my-item': isMyItem(item) }"
                >
                  <div class="item-content">{{ item.content }}</div>
                  <div class="item-actions" v-if="isMyItem(item)">
                    <el-icon class="action-icon edit" @click="handleEdit(item)"><Edit /></el-icon>
                    <el-icon class="action-icon delete" @click="handleDelete(item)"><Delete /></el-icon>
                  </div>
                </div>
              </div>
              <div v-else class="empty-cell">-</div>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </div>

    <!-- Edit Dialog -->
    <el-dialog v-model="showEditDialog" title="编辑学习进度" width="500px">
      <el-input
        v-model="editForm.content"
        type="textarea"
        :rows="4"
        placeholder="请输入内容..."
      />
      <template #footer>
        <el-button @click="showEditDialog = false">取消</el-button>
        <el-button type="primary" @click="submitEdit" :loading="editing">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, reactive } from 'vue'
import api from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Edit, Delete } from '@element-plus/icons-vue'

const props = defineProps({
  teamId: {
    type: [String, Number],
    required: true
  },
  members: {
    type: Array,
    default: () => []
  }
})

const loading = ref(false)
const feed = ref([])
const myContent = ref('')
const submitting = ref(false)

const currentUser = JSON.parse(localStorage.getItem('user') || '{}')
const showEditDialog = ref(false)
const editForm = reactive({
  id: null,
  content: ''
})
const editing = ref(false)

const isMyItem = (item) => {
  return item.user_id === currentUser.id
}

const handleEdit = (item) => {
  editForm.id = item.id
  editForm.content = item.content
  showEditDialog.value = true
}

const handleDelete = (item) => {
  ElMessageBox.confirm('确定删除这条进度吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(async () => {
    try {
      await api.delete(`/learning/${item.id}`)
      ElMessage.success('删除成功')
      fetchFeed()
    } catch (error) {
      ElMessage.error('删除失败')
    }
  }).catch(() => {})
}

const submitEdit = async () => {
  if (!editForm.content.trim()) {
    ElMessage.warning('内容不能为空')
    return
  }
  
  editing.value = true
  try {
    await api.put(`/learning/${editForm.id}`, {
      content: editForm.content
    })
    ElMessage.success('更新成功')
    showEditDialog.value = false
    fetchFeed()
  } catch (error) {
    ElMessage.error('更新失败')
  } finally {
    editing.value = false
  }
}
const dateColumns = computed(() => {
  const days = []
  for (let i = 0; i < 7; i++) {
    const d = new Date()
    d.setDate(d.getDate() - i)
    
    const year = d.getFullYear()
    const month = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    const key = `${year}-${month}-${day}`
    
    const label = i === 0 ? '今天' : (i === 1 ? '昨天' : `${month}-${day}`)
    days.push({ key, label })
  }
  return days
})

// Transform data for table
const tableData = computed(() => {
  // Map: UserId -> { name, avatar, data: { dateKey: [items] } }
  const userMap = new Map()
  
  // Initialize with all members
  props.members.forEach(m => {
    // API returns user_id for members list, support both id and user_id just in case
    const uid = m.user_id || m.id
    if (uid) {
      userMap.set(uid, {
        id: uid,
        name: m.nickname || m.username,
        avatar: m.avatar,
        data: {}
      })
    }
  })
  
  // Fill in feed data
  feed.value.forEach(item => {
    // Use local date for matching
    const d = new Date(item.created_at)
    const year = d.getFullYear()
    const month = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    const dateKey = `${year}-${month}-${day}`
    
    if (userMap.has(item.user_id)) {
      const userData = userMap.get(item.user_id)
      if (!userData.data[dateKey]) {
        userData.data[dateKey] = []
      }
      userData.data[dateKey].push(item)
    }
  })
  
  return Array.from(userMap.values())
})

const fetchFeed = async () => {
  loading.value = true
  try {
    const res = await api.get(`/learning/team/${props.teamId}`)
    feed.value = res.data
  } catch (error) {
    ElMessage.error('获取进度失败')
  } finally {
    loading.value = false
  }
}

const submitProgress = async () => {
  if (!myContent.value.trim()) {
    ElMessage.warning('请输入内容')
    return
  }
  
  submitting.value = true
  try {
    await api.post('/learning', {
      team_id: props.teamId,
      content: myContent.value,
      progress: 0
    })
    
    ElMessage.success('发布成功')
    myContent.value = ''
    fetchFeed()
  } catch (error) {
    ElMessage.error('发布失败')
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchFeed()
})

watch(() => props.teamId, () => {
  fetchFeed()
})
</script>

<style scoped>
.team-learning-container {
  padding: 20px;
  height: 100%;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.input-section {
  flex-shrink: 0;
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 10px;
}
.feed-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.feed-section h3 {
  margin: 0 0 15px 0;
  color: #606266;
}
.feed-list {
  flex: 1;
  overflow: auto;
  padding-right: 5px;
  background: #fff;
  border-radius: 8px;
  border: 1px solid #ebeef5;
}
.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
}
.username {
  font-weight: 600;
  color: #303133;
  font-size: 13px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.day-content {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.progress-item {
  background: #f0f9eb;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  color: #606266;
  border: 1px solid #e1f3d8;
  position: relative;
  group: hover;
}
.progress-item:hover {
  background: #e1f3d8;
}
.item-content {
  white-space: pre-wrap;
  word-break: break-all;
}
.item-actions {
  display: none;
  position: absolute;
  right: 4px;
  top: 4px;
  background: rgba(255,255,255,0.9);
  padding: 2px;
  border-radius: 4px;
  gap: 4px;
}
.progress-item:hover .item-actions {
  display: flex;
}
.action-icon {
  cursor: pointer;
  padding: 2px;
}
.action-icon.edit:hover {
  color: #409EFF;
}
.action-icon.delete:hover {
  color: #F56C6C;
}
.empty-cell {
  color: #dcdfe6;
  text-align: center;
}
</style>
