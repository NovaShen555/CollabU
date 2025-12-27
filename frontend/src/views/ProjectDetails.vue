<template>
  <div class="project-details-container">
    <div v-if="loading" class="loading">
      <el-skeleton :rows="5" animated />
    </div>

    <div v-else class="content">
      <!-- 标题已移除以增大主内容空间 -->
      <!-- 项目描述移至侧边栏 -->

      <div v-if="showGantt" class="gantt-view" key="gantt-view">
        <GanttChart :project-id="project.id" />
      </div>

      <div v-else class="task-tree-view" key="list-view">
        <el-table
          :data="taskTree"
          style="width: 100%; margin-bottom: 20px;"
          row-key="id"
          border
          default-expand-all
          :tree-props="{ children: 'children', hasChildren: 'hasChildren' }"
        >
          <el-table-column prop="title" label="任务名称" min-width="300">
            <template #default="scope">
              <span class="task-title" :class="{ 'is-completed': scope.row.status === 'completed' }" @click="handleTaskClick(scope.row)">
                {{ scope.row.title }}
              </span>
              <el-tag v-if="scope.row.children && scope.row.children.length" size="small" type="info" class="subtask-count">
                {{ scope.row.children.length }}
              </el-tag>
            </template>
          </el-table-column>

          <el-table-column label="优先级" width="100" align="center">
            <template #default="scope">
              <el-select v-model="scope.row.priority" size="small" @change="updateTaskPriority(scope.row)">
                <el-option label="高" value="high" />
                <el-option label="中" value="medium" />
                <el-option label="低" value="low" />
              </el-select>
            </template>
          </el-table-column>

          <el-table-column label="进度" width="150" align="center">
            <template #default="scope">
              <el-slider v-model="scope.row.progress" :max="100" size="small" @change="updateTaskProgressInList(scope.row)" />
            </template>
          </el-table-column>

          <el-table-column label="负责人" width="140" align="center">
            <template #default="scope">
                <div class="assignee-list">
                  <template v-if="scope.row.participants && scope.row.participants.length">
                    <el-avatar v-for="u in scope.row.participants.slice(0, 2)" :key="u.id" :size="24" :title="u.username" class="participant-avatar">
                      {{ u.nickname || u.username.charAt(0).toUpperCase() }}
                    </el-avatar>
                    <span v-if="scope.row.participants.length > 2" class="more-tag">+{{ scope.row.participants.length - 2 }}</span>
                  </template>
                  <el-tooltip content="加入任务" placement="top">
                    <el-button link size="small" icon="Plus" circle @click.stop="joinTask(scope.row)" class="join-btn" />
                  </el-tooltip>
                </div>
            </template>
          </el-table-column>

          <el-table-column label="时间安排" width="240" align="center">
            <template #default="scope">
               <el-date-picker
                 v-model="scope.row.dateRange"
                 type="daterange"
                 size="small"
                 range-separator="-"
                 start-placeholder="开始"
                 end-placeholder="结束"
                 value-format="YYYY-MM-DD"
                 style="width: 100%"
                 @change="updateTaskDates(scope.row)"
               />
            </template>
          </el-table-column>

          <el-table-column label="操作" width="120" align="center">
            <template #default="scope">
               <el-tooltip content="添加子任务" placement="top">
                 <el-button link type="primary" icon="Plus" @click="openAddSubtask(scope.row)" />
               </el-tooltip>
               <el-tooltip content="删除任务" placement="top">
                 <el-button link type="danger" icon="Delete" @click="deleteTask(scope.row.id)" />
               </el-tooltip>
               <el-tooltip content="详情" placement="top">
                 <el-button link icon="More" @click="handleTaskClick(scope.row)" />
               </el-tooltip>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </div>

    <!-- 新建/添加子任务弹窗 -->
    <el-dialog v-model="showCreateTaskDialog" :title="createDialogTitle" width="40%">
      <el-form :model="createTaskForm" label-width="80px">
        <el-form-item label="标题" required>
          <el-input v-model="createTaskForm.title" placeholder="请输入任务标题" />
        </el-form-item>
        <el-form-item label="描述">
          <MdEditor
            v-model="createTaskForm.description"
            :preview="false"
            style="height: 200px"
            @onUploadImg="handleCreateTaskUpload"
          />
        </el-form-item>
        <el-form-item label="优先级">
          <el-select v-model="createTaskForm.priority">
            <el-option label="高" value="high" />
            <el-option label="中" value="medium" />
            <el-option label="低" value="low" />
          </el-select>
        </el-form-item>
        <el-form-item label="起止日期">
          <el-date-picker
            v-model="createTaskForm.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
            style="width: 100%"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateTaskDialog = false">取消</el-button>
        <el-button type="primary" @click="handleCreateTask">确定</el-button>
      </template>
    </el-dialog>

    <!-- 任务详情抽屉 -->
    <el-drawer
      v-model="showTaskDrawer"
      title="任务详情"
      direction="rtl"
      size="600px"
    >
      <div v-if="currentTask">
        <div class="drawer-header-content">
           <h3>{{ currentTask.title }}</h3>
           <el-tag :type="getStatusType(currentTask.status)">{{ getStatusText(currentTask.status) }}</el-tag>
        </div>

        <div class="task-desc-section">
          <div class="desc-header">
            <span>任务描述</span>
            <el-button v-if="!editingTaskDesc" type="primary" link @click="startEditTaskDesc">编辑</el-button>
            <template v-else>
              <el-button type="primary" link @click="saveTaskDesc">保存</el-button>
              <el-button link @click="cancelEditTaskDesc">取消</el-button>
            </template>
          </div>
          <MdEditor
            v-if="editingTaskDesc"
            v-model="taskDescEdit"
            :preview="false"
            style="height: 250px"
            @onUploadImg="handleTaskDescUpload"
          />
          <MdPreview v-else :modelValue="currentTask.description || '无描述'" class="md-preview" />
        </div>

        <el-descriptions :column="1" border size="small">
          <el-descriptions-item label="优先级">
            <el-tag size="small" :type="getPriorityType(currentTask.priority)">{{ getPriorityText(currentTask.priority) }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="进度">
            <el-slider v-model="currentTask.progress" size="small" @change="updateTaskProgress" style="max-width: 200px" />
          </el-descriptions-item>
          <el-descriptions-item label="时间">
            {{ currentTask.start_date || '-' }} 至 {{ currentTask.end_date || '-' }}
          </el-descriptions-item>
        </el-descriptions>

        <el-divider content-position="left">参与者</el-divider>
        <div class="participants-section">
          <el-avatar v-for="u in currentTask.participants" :key="u.id" :size="30" :title="u.username">
            {{ u.nickname || u.username.charAt(0).toUpperCase() }}
          </el-avatar>
          <el-button size="small" circle icon="Plus" @click="joinTask(currentTask)" title="加入任务" />
        </div>

        <el-divider />
        
        <TaskDetail :task-id="currentTask.id" :project-id="project.id" />

      </div>
    </el-drawer>

  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ArrowLeft, Check, Plus, Delete } from '@element-plus/icons-vue'
import { MdEditor, MdPreview } from 'md-editor-v3'
import 'md-editor-v3/lib/style.css'
import TaskDetail from '../components/TaskDetail.vue'
import GanttChart from '../components/GanttChart.vue'

const route = useRoute()
const router = useRouter()
const projectId = route.params.projectId

const loading = ref(true)
const project = ref({})
const tasks = ref([])
const showGantt = ref(localStorage.getItem('projectView') === 'gantt')
const showCreateTaskDialog = ref(false)
const showTaskDrawer = ref(false)
const currentTask = ref(null)
const createDialogTitle = ref('新建任务')
const parentTaskForCreate = ref(null)
const editingProjectDesc = ref(false)
const projectDescEdit = ref('')
const editingTaskDesc = ref(false)
const taskDescEdit = ref('')

const createTaskForm = reactive({
  title: '',
  description: '',
  priority: 'medium',
  dateRange: []
})

// Build a single unified tree
const taskTree = computed(() => {
  return buildTree(null, tasks.value)
})

const buildTree = (parentId, allTasks) => {
  return allTasks
    .filter(t => {
      if (parentId === null) {
        return !t.parent_id // Match null, undefined, or 0
      }
      return t.parent_id === parentId
    })
    .map(t => ({
      ...t,
      label: t.title,
      children: buildTree(t.id, allTasks),
      dateRange: [t.start_date, t.end_date]
    }))
    .sort((a, b) => a.id - b.id) // Or sort by custom order
}

const fetchProjectDetails = async () => {
  loading.value = true
  try {
    const [projectRes, tasksRes] = await Promise.all([
      api.get(`/projects/${projectId}`),
      api.get(`/tasks?project_id=${projectId}&fetch_all=true`)
    ])
    project.value = projectRes.data
    tasks.value = tasksRes.data
  } catch (error) {
    console.error(error)
    ElMessage.error('获取项目信息失败')
  } finally {
    loading.value = false
  }
}

const refreshTasks = async () => {
  try {
    const res = await api.get(`/tasks?project_id=${projectId}&fetch_all=true`)
    tasks.value = res.data
  } catch (error) {
    console.error(error)
  }
}

const openCreateRootTask = () => {
  parentTaskForCreate.value = null
  createDialogTitle.value = '新建任务'
  resetForm()
  showCreateTaskDialog.value = true
}

const openAddSubtask = (parent) => {
  parentTaskForCreate.value = parent
  createDialogTitle.value = `为 "${parent.title}" 添加子任务`
  resetForm()
  showCreateTaskDialog.value = true
}

const resetForm = () => {
  createTaskForm.title = ''
  createTaskForm.description = ''
  createTaskForm.priority = 'medium'
  createTaskForm.dateRange = []
}

const handleCreateTask = async () => {
  if (!createTaskForm.title) {
    ElMessage.warning('请输入任务标题')
    return
  }
  
  const payload = {
    project_id: projectId,
    parent_id: parentTaskForCreate.value ? parentTaskForCreate.value.id : null,
    title: createTaskForm.title,
    description: createTaskForm.description,
    priority: createTaskForm.priority,
    status: 'pending',
    start_date: createTaskForm.dateRange?.[0],
    end_date: createTaskForm.dateRange?.[1]
  }
  
  try {
    await api.post('/tasks', payload)
    ElMessage.success('任务创建成功')
    showCreateTaskDialog.value = false
    refreshTasks()
  } catch (error) {
    console.error(error)
  }
}

const handleTaskClick = (task) => {
  currentTask.value = JSON.parse(JSON.stringify(task))
  showTaskDrawer.value = true
}

const updateTaskStatus = async (task, val) => {
  try {
    await api.put(`/tasks/${task.id}`, { status: val })
    ElMessage.success('状态更新成功')
    refreshTasks()
  } catch (error) {
    console.error(error)
    // Revert visually if failed (complex with tree prop binding, simplified here)
  }
}

const updateTaskDates = async (task) => {
  try {
    await api.put(`/tasks/${task.id}`, {
      start_date: task.dateRange?.[0],
      end_date: task.dateRange?.[1]
    })
    ElMessage.success('时间更新成功')
  } catch (error) {
    console.error(error)
    ElMessage.error('更新失败')
  }
}

const updateTaskPriority = async (task) => {
  try {
    await api.put(`/tasks/${task.id}`, { priority: task.priority })
    ElMessage.success('优先级已更新')
  } catch (error) {
    console.error(error)
    ElMessage.error('更新失败')
  }
}

const updateTaskProgressInList = async (task) => {
  try {
    await api.put(`/tasks/${task.id}`, { progress: task.progress })
    ElMessage.success('进度已更新')
  } catch (error) {
    console.error(error)
    ElMessage.error('更新失败')
  }
}

const updateTaskProgress = async (val) => {
   try {
    await api.put(`/tasks/${currentTask.value.id}`, { progress: val })
  } catch (error) {
    console.error(error)
  }
}

const joinTask = async (task) => {
  try {
    await api.post(`/tasks/${task.id}/join`)
    ElMessage.success('已认领任务')
    refreshTasks()
    if (currentTask.value && currentTask.value.id === task.id) {
       // Refresh drawer data
       const res = await api.get(`/tasks/${task.id}`)
       currentTask.value.participants = res.data.participants
    }
  } catch (error) {
    if (error.response && error.response.status === 400) {
       ElMessage.warning('你已经参与该任务了')
    } else {
       console.error(error)
    }
  }
}

const deleteTask = async (taskId) => {
  ElMessageBox.confirm('确定要删除该任务及其所有子任务吗？', '警告', { type: 'warning' })
    .then(async () => {
      try {
        await api.delete(`/tasks/${taskId}`)
        ElMessage.success('删除成功')
        refreshTasks()
      } catch (error) {
        ElMessage.error('删除失败')
      }
    })
    .catch(() => {})
}

// 项目描述编辑
const startEditProjectDesc = () => {
  projectDescEdit.value = project.value.description || ''
  editingProjectDesc.value = true
}

const cancelEditProjectDesc = () => {
  editingProjectDesc.value = false
}

const saveProjectDesc = async () => {
  try {
    await api.put(`/projects/${projectId}`, { description: projectDescEdit.value })
    project.value.description = projectDescEdit.value
    editingProjectDesc.value = false
    ElMessage.success('描述已更新')
  } catch (error) {
    ElMessage.error('更新失败')
  }
}

const handleProjectDescUpload = async (files, callback) => {
  const urls = []
  for (const file of files) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('team_id', project.value.team_id)
    try {
      const res = await api.post('/files/upload', formData)
      const isImage = file.type.startsWith('image/')
      urls.push(isImage ? `${res.data.url}?inline=true` : res.data.url)
    } catch (e) {
      ElMessage.error(`上传 ${file.name} 失败`)
    }
  }
  callback(urls)
}

// 任务描述编辑
const startEditTaskDesc = () => {
  taskDescEdit.value = currentTask.value.description || ''
  editingTaskDesc.value = true
}

const cancelEditTaskDesc = () => {
  editingTaskDesc.value = false
}

const saveTaskDesc = async () => {
  try {
    await api.put(`/tasks/${currentTask.value.id}`, { description: taskDescEdit.value })
    currentTask.value.description = taskDescEdit.value
    editingTaskDesc.value = false
    ElMessage.success('描述已更新')
  } catch (error) {
    ElMessage.error('更新失败')
  }
}

const handleTaskDescUpload = async (files, callback) => {
  const urls = []
  for (const file of files) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('task_id', currentTask.value.id)
    try {
      const res = await api.post('/files/upload', formData)
      const isImage = file.type.startsWith('image/')
      urls.push(isImage ? `${res.data.url}?inline=true` : res.data.url)
    } catch (e) {
      ElMessage.error(`上传 ${file.name} 失败`)
    }
  }
  callback(urls)
}

const handleCreateTaskUpload = async (files, callback) => {
  const urls = []
  for (const file of files) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('team_id', project.value.team_id)
    try {
      const res = await api.post('/files/upload', formData)
      const isImage = file.type.startsWith('image/')
      urls.push(isImage ? `${res.data.url}?inline=true` : res.data.url)
    } catch (e) {
      ElMessage.error(`上传 ${file.name} 失败`)
    }
  }
  callback(urls)
}

const goBack = () => {}

const getStatusType = (status) => {
  const map = { planning: 'info', in_progress: 'primary', completed: 'success', archived: 'warning' }
  return map[status] || 'info'
}

const getStatusText = (status) => {
  const map = { planning: '规划中', pending: '待处理', in_progress: '进行中', completed: '已完成', archived: '已归档' }
  return map[status] || status
}

const getPriorityType = (p) => {
  const map = { high: 'danger', medium: 'warning', low: 'info' }
  return map[p]
}

const getPriorityText = (p) => {
  const map = { high: '高', medium: '中', low: '低' }
  return map[p] || p
}

// 切换视图时刷新数据并保存状态
watch(showGantt, (newVal) => {
  localStorage.setItem('projectView', newVal ? 'gantt' : 'list')
  // 切换视图时刷新数据
  refreshTasks()
})

watch(() => route.query.view, (val) => {
  if (val === 'gantt') showGantt.value = true
  if (val === 'list') showGantt.value = false
})

watch(() => route.query.action, (val) => {
  if (val === 'create_task') {
    openCreateRootTask()
  }
})

onMounted(async () => {
  await fetchProjectDetails()
  if (route.query.taskId) {
    const task = tasks.value.find(t => t.id == route.query.taskId)
    if (task) {
      handleTaskClick(task)
    }
  }
  if (route.query.view === 'gantt') showGantt.value = true
  if (route.query.view === 'list') showGantt.value = false
  if (route.query.action === 'create_task') openCreateRootTask()
})
</script>

<style scoped>
.project-details-container {
  padding: 20px;
  height: 100%;
  display: flex;
  flex-direction: column;
}
.content {
  height: 100%;
  display: flex;
  flex-direction: column;
}
.gantt-view {
  flex: 1;
  display: flex;
}
.description-section {
  margin-bottom: 20px;
  padding: 15px;
  background: #f9f9f9;
  border-radius: 8px;
}
.desc-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
  font-weight: bold;
}
.md-preview {
  background: white;
  padding: 10px;
  border-radius: 4px;
  min-height: 60px;
}
.description {
  color: #666;
  margin-bottom: 20px;
  padding-left: 55px;
}

/* Tree Table View Styles */
.task-tree-view {
  flex: 1;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 12px 0 rgba(0,0,0,0.1);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding: 20px;
}
/* Removed old custom styles for manual tree rows */
.task-title {
  font-weight: 500;
  cursor: pointer;
}
.task-title:hover {
  color: #409eff;
}
.task-title.is-completed {
  text-decoration: line-through;
  color: #999;
}
.subtask-count {
  margin-left: 5px;
  font-size: 10px;
  height: 16px;
  line-height: 14px;
  padding: 0 4px;
}
.assignee-list {
  display: flex;
  justify-content: center;
  align-items: center;
}
.more-tag {
  font-size: 10px;
  color: #999;
  margin-left: 2px;
}
.participant-avatar {
  border: 2px solid white;
  margin-right: -8px;
  position: relative;
  z-index: 1;
}
.participant-avatar:hover {
  z-index: 10;
}
.join-btn {
  margin-left: 12px;
}
.drawer-header-content {
  display: flex;
  align-items: center;
  gap: 15px;
}
.task-desc-section {
  margin: 15px 0;
}
.drawer-desc {
  color: #555;
  margin: 10px 0 20px;
  white-space: pre-wrap;
}
.participants-section {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 20px;
}
</style>
