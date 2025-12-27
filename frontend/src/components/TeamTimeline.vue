<template>
  <div class="team-timeline-container">
    <div class="header">
      <h3>成果记录</h3>
      <el-button type="primary" @click="showDialog = true">添加成果</el-button>
    </div>

    <div v-if="loading" class="loading">
      <el-skeleton :rows="5" animated />
    </div>

    <div v-else-if="events.length === 0" class="empty">
      <el-empty description="暂无成果记录，快来记录团队的里程碑吧！" />
    </div>

    <div v-else class="timeline-content">
      <el-timeline>
        <el-timeline-item
          v-for="event in events"
          :key="event.id"
          :timestamp="formatDate(event.event_date)"
          placement="top"
          :type="getEventType(event)"
          :color="getEventColor(event)"
        >
          <el-card class="event-card">
            <div class="event-header">
              <h4>{{ event.title }}</h4>
              <div class="event-actions" v-if="isCreator(event)">
                 <el-button type="primary" link :icon="Edit" @click="editEvent(event)" />
                 <el-popconfirm title="确定删除这条记录吗？" @confirm="deleteEvent(event.id)">
                    <template #reference>
                      <el-button type="danger" link :icon="Delete" />
                    </template>
                 </el-popconfirm>
              </div>
            </div>
            <div class="event-desc" v-if="event.description">
              <MdPreview :modelValue="event.description" language="zh-CN" />
            </div>
            
            <div v-if="event.files && event.files.length > 0" class="event-files">
              <div v-for="file in event.files" :key="file.id" class="file-item">
                <el-icon><Document /></el-icon>
                <a :href="file.url" target="_blank">{{ file.filename }}</a>
              </div>
            </div>
            
            <div class="event-footer">
              <span class="creator">
                <el-avatar :size="20" :src="event.creator_avatar" class="avatar-small">
                   {{ event.creator_name ? event.creator_name.charAt(0).toUpperCase() : 'U' }}
                </el-avatar>
                {{ event.creator_name }}
              </span>
              <span class="created-at">记录于 {{ formatDate(event.created_at) }}</span>
            </div>
          </el-card>
        </el-timeline-item>
      </el-timeline>
    </div>

    <!-- Dialog -->
    <el-dialog v-model="showDialog" :title="editingId ? '编辑成果记录' : '添加成果记录'" width="800px" @closed="resetForm">
      <el-form :model="form" label-width="80px">
        <el-form-item label="标题" required>
          <el-input v-model="form.title" placeholder="例如：完成第一阶段开发" />
        </el-form-item>
        <el-form-item label="日期">
           <el-date-picker v-model="form.event_date" type="date" placeholder="选择日期" style="width: 100%" />
        </el-form-item>
        <el-form-item label="描述">
          <div style="width: 100%; border: 1px solid #dcdfe6; border-radius: 4px; overflow: hidden;">
             <div style="padding: 5px 10px; border-bottom: 1px solid #dcdfe6; background-color: #f5f7fa; display: flex; justify-content: flex-end;">
                <el-upload
                  action=""
                  :http-request="handleUploadFile"
                  :show-file-list="false"
                  :disabled="uploading"
                >
                  <el-button size="small" :loading="uploading" link type="primary">插入附件</el-button>
                </el-upload>
             </div>
             <MdEditor 
                v-model="form.description" 
                language="zh-CN" 
                :toolbarsExclude="['save', 'github']" 
                :preview="false" 
                style="height: 300px" 
                @onUploadImg="handleUploadImg"
             />
          </div>
        </el-form-item>
        <el-form-item label="附件">
          <el-upload
            ref="uploadRef"
            action="#"
            :auto-upload="false"
            :on-change="handleFileChange"
            :on-remove="handleFileRemove"
            :file-list="fileList"
            multiple
          >
            <el-button type="primary" link>点击上传文件</el-button>
          </el-upload>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="submitEvent" :loading="submitting">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import api from '../api'
import { ElMessage } from 'element-plus'
import { MdEditor, MdPreview } from 'md-editor-v3'
import 'md-editor-v3/lib/style.css'
import { Document, Delete, Edit } from '@element-plus/icons-vue'

const props = defineProps({
  teamId: {
    type: [String, Number],
    required: true
  }
})

const loading = ref(false)
const events = ref([])
const showDialog = ref(false)
const submitting = ref(false)
const uploading = ref(false)
const editingId = ref(null)
const form = reactive({
  title: '',
  description: '',
  event_date: new Date()
})
const fileList = ref([])
const currentUser = JSON.parse(localStorage.getItem('user') || '{}')

const fetchEvents = async () => {
  loading.value = true
  try {
    const res = await api.get(`/timeline/team/${props.teamId}`)
    events.value = res.data
  } catch (error) {
    console.error(error)
    ElMessage.error('获取成果记录失败')
  } finally {
    loading.value = false
  }
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleDateString('zh-CN')
}

const getEventType = (event) => {
  // Can be customized based on content
  return 'primary'
}

const getEventColor = (event) => {
  return '#409EFF'
}

const isCreator = (event) => {
  return event.created_by === currentUser.id
}

const handleFileChange = (file, files) => {
  fileList.value = files
}

const handleFileRemove = (file, files) => {
  fileList.value = files
}

const handleUploadImg = async (files, callback) => {
  const res = await Promise.all(
    files.map(file => {
      return new Promise(async (resolve, reject) => {
        const formData = new FormData()
        formData.append('file', file)
        formData.append('team_id', props.teamId)
        if (editingId.value) {
          formData.append('timeline_event_id', editingId.value)
        }

        try {
          const res = await api.post('/files/upload', formData, {
            headers: {
              'Content-Type': 'multipart/form-data'
            }
          })
          resolve(`${res.data.url}?inline=true`)
        } catch (error) {
          reject(error)
        }
      })
    })
  )

  callback(res)
}

const handleUploadFile = async (options) => {
  uploading.value = true
  const formData = new FormData()
  formData.append('file', options.file)
  formData.append('team_id', props.teamId)
  if (editingId.value) {
    formData.append('timeline_event_id', editingId.value)
  }
  
  try {
    const res = await api.post('/files/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })
    
    // Default to download link, not inline
    const url = res.data.url
    
    const isImage = options.file.type.startsWith('image/')
    const markdown = isImage ? `![${options.file.name}](${url}?inline=true)` : `[${options.file.name}](${url})`
    
    // Append to content
    if (!form.description) form.description = ''
    form.description += '\n' + markdown + '\n'
    ElMessage.success('附件上传成功')
  } catch (error) {
    ElMessage.error('上传失败')
  } finally {
    uploading.value = false
  }
}

const editEvent = (event) => {
  editingId.value = event.id
  form.title = event.title
  form.description = event.description
  form.event_date = event.event_date ? new Date(event.event_date) : new Date()
  fileList.value = [] // Reset files for now, as existing files are not in fileList
  showDialog.value = true
}

const submitEvent = async () => {
  if (!form.title) {
    ElMessage.warning('请输入标题')
    return
  }
  
  submitting.value = true
  try {
    let eventId
    
    if (editingId.value) {
      // Update
      await api.put(`/timeline/${editingId.value}`, {
        title: form.title,
        description: form.description,
        event_date: form.event_date
      })
      eventId = editingId.value
      ElMessage.success('更新成功')
    } else {
      // Create
      const res = await api.post('/timeline', {
        team_id: props.teamId,
        title: form.title,
        description: form.description,
        event_date: form.event_date
      })
      eventId = res.data.id
      ElMessage.success('添加成功')
    }
    
    // Upload files if any (for both create and update)
    if (fileList.value.length > 0) {
      const uploadPromises = fileList.value.map(file => {
        const formData = new FormData()
        formData.append('file', file.raw)
        formData.append('timeline_event_id', eventId)
        formData.append('team_id', props.teamId) 
        return api.post('/files/upload', formData, {
          headers: { 'Content-Type': 'multipart/form-data' }
        })
      })
      
      await Promise.all(uploadPromises)
    }
    
    showDialog.value = false
    resetForm()
    fetchEvents()
  } catch (error) {
    console.error(error)
    ElMessage.error('操作失败')
  } finally {
    submitting.value = false
  }
}

const resetForm = () => {
  editingId.value = null
  form.title = ''
  form.description = ''
  form.event_date = new Date()
  fileList.value = []
}

const deleteEvent = async (id) => {
  try {
    await api.delete(`/timeline/${id}`)
    ElMessage.success('删除成功')
    fetchEvents()
  } catch (error) {
    ElMessage.error('删除失败')
  }
}

onMounted(() => {
  fetchEvents()
})
</script>

<style scoped>
.team-timeline-container {
  padding: 20px;
  height: 100%;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
.header h3 {
  margin: 0;
  color: #303133;
}
.timeline-content {
  flex: 1;
  overflow: auto;
  padding-right: 20px; /* space for scrollbar */
}
.event-card {
  border-radius: 8px;
}
.event-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 8px;
}
.event-header h4 {
  margin: 0;
  font-size: 16px;
  color: #303133;
}
.event-desc {
  color: #606266;
  font-size: 14px;
  margin-bottom: 12px;
  white-space: pre-wrap;
}
.event-files {
  margin-bottom: 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.file-item {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 13px;
}
.file-item a {
  color: #409EFF;
  text-decoration: none;
}
.file-item a:hover {
  text-decoration: underline;
}
.event-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: #909399;
  border-top: 1px solid #EBEEF5;
  padding-top: 8px;
}
.creator {
  display: flex;
  align-items: center;
  gap: 6px;
}
.avatar-small {
  background: #409EFF;
  color: #fff;
  font-size: 10px;
}
</style>
