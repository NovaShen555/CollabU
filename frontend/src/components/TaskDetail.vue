<template>
  <div class="task-detail-component">
    <el-tabs v-model="activeTab">
      <el-tab-pane label="子任务" name="subtasks">
        <div class="subtasks-container">
           <el-tree
             v-if="subtasks.length > 0"
             :data="subtasks"
             node-key="id"
             default-expand-all
             :expand-on-click-node="false"
           >
             <template #default="{ node, data }">
               <div class="custom-tree-node">
                 <div class="node-left">
                   <el-checkbox v-model="data.completed" @change="toggleSubtask(data)" />
                   <span class="node-title" :class="{ completed: data.completed }">{{ data.title }}</span>
                 </div>
                 
                 <div class="node-right">
                   <el-date-picker
                     v-model="data.dateRange"
                     type="daterange"
                     size="small"
                     start-placeholder="开始"
                     end-placeholder="结束"
                     style="width: 220px; margin-right: 10px;"
                     value-format="YYYY-MM-DD"
                     @change="updateTaskDates(data)"
                     @click.stop
                   />
                   
                   <el-button link icon="Plus" size="small" @click.stop="openAddSubtask(data)">子任务</el-button>
                   <el-button link icon="Delete" size="small" type="danger" @click.stop="deleteSubtask(data.id)"></el-button>
                 </div>
               </div>
             </template>
           </el-tree>
           
           <div v-else class="empty-subtasks">
             <el-empty description="暂无子任务" :image-size="60" />
           </div>

           <div class="add-root-subtask">
             <el-button type="primary" plain style="width: 100%" icon="Plus" @click="openAddSubtask(null)">
               添加一级子任务
             </el-button>
           </div>
        </div>
      </el-tab-pane>
      
      <el-tab-pane label="评论" name="comments">
        <div class="comments-list" ref="commentsRef">
          <div v-for="comment in comments" :key="comment.id" class="comment-item">
            <el-avatar :size="30" :src="comment.avatar">
              {{ displayName(comment).charAt(0).toUpperCase() }}
            </el-avatar>
            <div class="comment-content">
              <div class="comment-header">
                <span class="username">{{ displayName(comment) }}</span>
                <span class="time">{{ formatTime(comment.created_at) }}</span>
              </div>
              <p class="text">{{ comment.content }}</p>
            </div>
          </div>
          <el-empty v-if="comments.length === 0" description="暂无评论" :image-size="60" />
        </div>
        <div class="comment-input">
          <el-input v-model="newComment" placeholder="写下你的评论..." type="textarea" :rows="2" />
          <el-button type="primary" size="small" @click="sendComment" :disabled="!newComment">发送</el-button>
        </div>
      </el-tab-pane>
      
      <el-tab-pane label="文件" name="files">
         <el-upload
           class="upload-demo"
           action="#"
           :http-request="handleUpload"
           :show-file-list="false"
         >
           <el-button type="primary" icon="Upload">上传文件</el-button>
         </el-upload>
         <div class="file-list">
            <div v-for="file in files" :key="file.id" class="file-item">
              <el-icon><Document /></el-icon>
              <span class="filename">{{ file.filename }}</span>
              <el-button type="primary" link @click="downloadFile(file)">下载</el-button>
              <el-button type="danger" link @click="deleteFile(file)">删除</el-button>
            </div>
            <el-empty v-if="files.length === 0" description="暂无文件" :image-size="60" />
         </div>
      </el-tab-pane>
    </el-tabs>

    <!-- 添加子任务弹窗 -->
    <el-dialog v-model="showAddDialog" :title="addDialogTitle" width="30%" append-to-body>
      <el-form :model="addForm">
        <el-form-item label="任务标题">
          <el-input v-model="addForm.title" placeholder="请输入任务标题" />
        </el-form-item>
        <el-form-item label="起止日期">
          <el-date-picker
            v-model="addForm.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始"
            end-placeholder="结束"
            value-format="YYYY-MM-DD"
            style="width: 100%"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAddDialog = false">取消</el-button>
        <el-button type="primary" @click="confirmAddSubtask">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useUserStore } from '../stores/user'
import api from '../api'
import { ElMessage } from 'element-plus'
import { Document, Upload, Delete, Plus } from '@element-plus/icons-vue'
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
dayjs.extend(utc)

const props = defineProps({
  taskId: { type: Number, required: true },
  projectId: { type: Number, required: true }
})

const userStore = useUserStore()
const activeTab = ref(localStorage.getItem('taskDetailTab') || 'subtasks')

// 保存标签页状态
watch(activeTab, (val) => {
  localStorage.setItem('taskDetailTab', val)
})

// Subtasks
const subtasks = ref([])
const showAddDialog = ref(false)
const addDialogTitle = ref('添加子任务')
const currentParent = ref(null)
const addForm = reactive({
  title: '',
  dateRange: []
})

// Comments
const comments = ref([])
const newComment = ref('')

// Files
const files = ref([])

const fetchSubtasks = async () => {
  try {
    // Fetch all project tasks to build the tree
    const res = await api.get(`/tasks?project_id=${props.projectId}&fetch_all=true`)
    const allTasks = res.data
    subtasks.value = buildTree(allTasks, props.taskId)
  } catch (error) {
    console.error(error)
  }
}

const buildTree = (tasks, parentId) => {
    return tasks
        .filter(t => t.parent_id === parentId) // Find direct children
        .map(t => ({
            ...t,
            label: t.title,
            children: buildTree(tasks, t.id), // Recursively find children
            completed: t.status === 'completed',
            dateRange: [t.start_date, t.end_date]
        }))
}

const openAddSubtask = (parent) => {
  currentParent.value = parent
  addDialogTitle.value = parent ? `为 "${parent.title}" 添加子任务` : '添加一级子任务'
  addForm.title = ''
  addForm.dateRange = []
  showAddDialog.value = true
}

const confirmAddSubtask = async () => {
  if (!addForm.title) {
    ElMessage.warning('请输入标题')
    return
  }
  
  try {
    const parentId = currentParent.value ? currentParent.value.id : props.taskId
    
    await api.post('/tasks', {
      project_id: props.projectId,
      parent_id: parentId,
      title: addForm.title,
      status: 'pending',
      start_date: addForm.dateRange?.[0],
      end_date: addForm.dateRange?.[1]
    })
    
    ElMessage.success('添加成功')
    showAddDialog.value = false
    fetchSubtasks()
  } catch (error) {
    console.error(error)
  }
}

const toggleSubtask = async (sub) => {
  const newStatus = sub.completed ? 'completed' : 'pending'
  try {
    await api.put(`/tasks/${sub.id}`, { status: newStatus })
  } catch (error) {
    console.error(error)
    sub.completed = !sub.completed // Revert on error
  }
}

const updateTaskDates = async (sub) => {
  try {
    await api.put(`/tasks/${sub.id}`, {
      start_date: sub.dateRange?.[0],
      end_date: sub.dateRange?.[1]
    })
    ElMessage.success('时间更新成功')
  } catch (error) {
    console.error(error)
    ElMessage.error('更新失败')
  }
}

const deleteSubtask = async (id) => {
    try {
      await api.delete(`/tasks/${id}`)
      ElMessage.success('删除成功')
      fetchSubtasks()
    } catch (error) {
      ElMessage.error('删除失败')
    }
}

// Comments
const fetchComments = async () => {
  try {
    const res = await api.get(`/tasks/${props.taskId}/comments`)
    comments.value = res.data
  } catch (error) {
    console.error(error)
  }
}

const sendComment = async () => {
  try {
    await api.post(`/tasks/${props.taskId}/comments`, { content: newComment.value })
    newComment.value = ''
    fetchComments()
  } catch (error) {
    console.error(error)
  }
}

// Files
const handleUpload = async (options) => {
  const formData = new FormData()
  formData.append('file', options.file)
  formData.append('task_id', props.taskId)
  
  try {
    await api.post('/files/upload', formData)
    ElMessage.success('上传成功')
    fetchFiles()
  } catch (error) {
    ElMessage.error('上传失败')
  }
}

const fetchFiles = async () => {
  try {
    const res = await api.get(`/files?task_id=${props.taskId}`)
    files.value = res.data
  } catch (error) {
    console.error(error)
  }
}

const downloadFile = async (file) => {
  try {
    // file.url 是 /api/files/{uid}，需要去掉 /api 前缀
    const url = file.url.replace(/^\/api/, '')
    const res = await api.get(url, { responseType: 'blob' })
    const blobUrl = window.URL.createObjectURL(new Blob([res.data]))
    const link = document.createElement('a')
    link.href = blobUrl
    link.setAttribute('download', file.filename)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(blobUrl)
  } catch (error) {
    ElMessage.error('下载失败')
  }
}

const deleteFile = async (file) => {
  try {
    await api.delete(`/files/${file.uid}`)
    ElMessage.success('删除成功')
    fetchFiles()
  } catch (error) {
    ElMessage.error('删除失败')
  }
}

const displayName = (item) => {
  const n = item?.nickname
  if (n && n.trim().length > 0) return n.trim()
  return item?.username || ''
}

const formatTime = (iso) => {
  if (!iso) return ''
  return dayjs.utc(iso).local().format('MM-DD HH:mm')
}

watch(() => props.taskId, (newVal) => {
  if (newVal) {
    fetchSubtasks()
    fetchComments()
    fetchFiles()
  }
})

onMounted(() => {
  fetchSubtasks()
  fetchComments()
  fetchFiles()
})

onUnmounted(() => {
})
</script>

<style scoped>
.task-detail-component {
  height: 100%;
}
.subtasks-container {
  display: flex;
  flex-direction: column;
  gap: 15px;
}
.custom-tree-node {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 14px;
  padding-right: 8px;
  width: 100%;
}
.node-left {
  display: flex;
  align-items: center;
  gap: 8px;
}
.node-title {
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.node-title.completed {
  text-decoration: line-through;
  color: #999;
}
.node-right {
  display: flex;
  align-items: center;
}
.add-root-subtask {
  margin-top: 10px;
}

.comments-list {
  max-height: 300px;
  overflow-y: auto;
  margin-bottom: 10px;
}
.comment-item {
  display: flex;
  gap: 10px;
  margin-bottom: 15px;
}
.comment-header {
  font-size: 12px;
  color: #666;
  margin-bottom: 4px;
}
.comment-header .time {
  margin-left: 10px;
  opacity: 0.7;
}
.comment-input {
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.file-list {
  margin-top: 15px;
}
.file-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px;
  border-bottom: 1px solid #eee;
}
.file-item .filename {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
