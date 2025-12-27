<template>
  <div class="gantt-wrapper">
    <!-- 工具栏 -->
    <div class="gantt-toolbar">
      <div class="toolbar-left">
        <el-button type="primary" size="small" @click="showLinkDialog = true">
          管理依赖关系
        </el-button>
      </div>
      <div class="toolbar-right">
        <el-popover
          placement="bottom-end"
          title="连线图例"
          :width="250"
          trigger="hover"
        >
          <template #reference>
            <el-button link size="small">
              <el-icon><InfoFilled /></el-icon>
              <span style="margin-left: 4px">图例</span>
            </el-button>
          </template>
          <div class="legend-content">
            <div class="legend-item">
              <svg width="24" height="12" viewBox="0 0 24 12">
                <line x1="0" y1="6" x2="18" y2="6" stroke="#95a5a6" stroke-width="1.5" stroke-dasharray="3,3"></line>
                <polygon points="24,6 18,3 18,9" fill="#95a5a6"></polygon>
              </svg>
              <div class="legend-text">
                <span class="legend-label">PC</span>
                <span class="legend-desc">父子关系</span>
              </div>
            </div>
            <div class="legend-item">
              <svg width="24" height="12" viewBox="0 0 24 12">
                <line x1="0" y1="6" x2="18" y2="6" stroke="#3498db" stroke-width="2"></line>
                <polygon points="24,6 18,3 18,9" fill="#3498db"></polygon>
              </svg>
              <div class="legend-text">
                <span class="legend-label">FS</span>
                <span class="legend-desc">完成-开始</span>
              </div>
            </div>
            <div class="legend-item">
              <svg width="24" height="12" viewBox="0 0 24 12">
                <line x1="0" y1="6" x2="18" y2="6" stroke="#2ecc71" stroke-width="2"></line>
                <polygon points="24,6 18,3 18,9" fill="#2ecc71"></polygon>
              </svg>
              <div class="legend-text">
                <span class="legend-label">SS</span>
                <span class="legend-desc">开始-开始</span>
              </div>
            </div>
            <div class="legend-item">
              <svg width="24" height="12" viewBox="0 0 24 12">
                <line x1="0" y1="6" x2="18" y2="6" stroke="#e74c3c" stroke-width="2"></line>
                <polygon points="24,6 18,3 18,9" fill="#e74c3c"></polygon>
              </svg>
              <div class="legend-text">
                <span class="legend-label">FF</span>
                <span class="legend-desc">完成-完成</span>
              </div>
            </div>
            <div class="legend-item">
              <svg width="24" height="12" viewBox="0 0 24 12">
                <line x1="0" y1="6" x2="18" y2="6" stroke="#f39c12" stroke-width="2"></line>
                <polygon points="24,6 18,3 18,9" fill="#f39c12"></polygon>
              </svg>
              <div class="legend-text">
                <span class="legend-label">SF</span>
                <span class="legend-desc">开始-完成</span>
              </div>
            </div>
          </div>
        </el-popover>
      </div>
    </div>

    <!-- 甘特图 -->
    <div class="gantt-content">
      <Gantt
        ref="ganttRef"
        :dataConfig="dataConfig"
        :styleConfig="styleConfig"
        :eventConfig="eventConfig"
      />
    </div>

    <!-- 依赖关系管理弹窗 -->
    <el-dialog v-model="showLinkDialog" title="管理任务依赖关系" width="600px">
      <div class="link-form">
        <el-form :model="linkForm" label-width="100px" size="small">
          <el-form-item label="前置任务">
            <el-select v-model="linkForm.source" placeholder="选择前置任务" filterable>
              <el-option
                v-for="task in taskList"
                :key="task.id"
                :label="task.title"
                :value="task.id"
              />
            </el-select>
          </el-form-item>
          <el-form-item label="后续任务">
            <el-select v-model="linkForm.target" placeholder="选择后续任务" filterable>
              <el-option
                v-for="task in taskList"
                :key="task.id"
                :label="task.title"
                :value="task.id"
                :disabled="task.id === linkForm.source"
              />
            </el-select>
          </el-form-item>
          <el-form-item label="依赖类型">
            <el-select v-model="linkForm.type">
              <el-option label="完成-开始 (FS)" value="0" />
              <el-option label="开始-开始 (SS)" value="1" />
              <el-option label="完成-完成 (FF)" value="2" />
              <el-option label="开始-完成 (SF)" value="3" />
            </el-select>
          </el-form-item>
          <el-form-item>
            <el-button type="primary" @click="createLink">添加依赖</el-button>
          </el-form-item>
        </el-form>
      </div>

      <el-divider>现有依赖关系</el-divider>

      <el-table :data="linkList" size="small" max-height="300">
        <el-table-column label="前置任务" prop="sourceName" />
        <el-table-column label="后续任务" prop="targetName" />
        <el-table-column label="类型" width="120">
          <template #default="{ row }">
            {{ getLinkTypeName(row.type) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="80">
          <template #default="{ row }">
            <el-button type="danger" link size="small" @click="deleteLink(row.id)">
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, watch, onMounted, computed, nextTick } from 'vue'
import Gantt, { LinkType } from '@lee576/vue3-gantt'
import '@lee576/vue3-gantt/style.css'
import dayjs from 'dayjs'
import { useDebounceFn } from '@vueuse/core'
import api from '../api'
import { ElMessage } from 'element-plus'
import { Document, User, Menu, Fold, Expand, UserFilled, List, Calendar, Link, ChatDotRound, ArrowLeft, Plus, SwitchButton, InfoFilled } from '@element-plus/icons-vue'

const props = defineProps({
  projectId: {
    type: Number,
    required: true
  }
})

// 依赖关系管理
const showLinkDialog = ref(false)
const taskList = ref([])
const rawLinks = ref([])
const isInitialized = ref(false)
const ganttRef = ref(null)
const linkForm = reactive({
  source: '',
  target: '',
  type: '0'
})

// 计算依赖列表（带任务名称）
const linkList = computed(() => {
  return rawLinks.value.map(link => {
    const sourceTask = taskList.value.find(t => t.id === link.source)
    const targetTask = taskList.value.find(t => t.id === link.target)
    return {
      ...link,
      sourceName: sourceTask?.title || link.source,
      targetName: targetTask?.title || link.target
    }
  })
})

// 获取依赖类型名称
const getLinkTypeName = (type) => {
  const names = {
    '0': '完成-开始 (FS)',
    '1': '开始-开始 (SS)',
    '2': '完成-完成 (FF)',
    '3': '开始-完成 (SF)'
  }
  return names[String(type)] || type
}

// 优先级颜色映射
const priorityColorMap = {
  high: '#ef4444',
  medium: '#f59e0b',
  low: '#6b7280'
}

// 样式配置
const styleConfig = ref({
  headersHeight: 80,
  rowHeight: 50,
  setBarColor: (row) => {
    return priorityColorMap[row.priority] || '#3b82f6'
  },
  // 初始表格宽度（如果本地有保存则使用保存值）
  tableWidth: parseInt(localStorage.getItem('gantt-table-width') || '550')
})

// 监听表格宽度变化（通过 DOM 观察或定期检查）
// 注意：vue3-gantt 可能没有直接暴露宽度变化事件，我们通过 styleConfig 传递响应式对象
// 如果组件库直接修改了 tableWidth，这里可以监听到
watch(() => styleConfig.value.tableWidth, (newWidth) => {
  if (newWidth) {
    localStorage.setItem('gantt-table-width', String(newWidth))
  }
}, { deep: true })

// 实际更新任务日期的函数（带防抖）
const doUpdateBarDate = useDebounceFn(async (id, startDate, endDate) => {
  try {
    await api.put(`/tasks/${id}`, {
      start_date: startDate.split(' ')[0],
      end_date: endDate.split(' ')[0]
    })
    ElMessage.success('任务日期已更新')
  } catch (error) {
    ElMessage.error('更新任务失败')
    fetchData()
  }
}, 500)

// 更新任务日期（初始化完成前不执行）
const handleBarDateChange = (id, startDate, endDate) => {
  if (!isInitialized.value) return
  doUpdateBarDate(id, startDate, endDate)
}

// 更新任务进度
const handleProgressUpdate = async (detail) => {
  try {
    await api.put(`/tasks/${detail.taskId}`, {
      progress: Math.round(detail.newProgress * 100)
    })
    ElMessage.success('进度已更新')
  } catch (error) {
    ElMessage.error('更新进度失败')
  }
}

// 额外补充：如果组件库不支持双向绑定 tableWidth，可能需要通过事件回调
// 假设组件提供了 resize 事件，或者我们手动保存
const eventConfig = ref({
  queryTask: async (startDate, endDate, mode) => {
    await fetchData(startDate, endDate)
  },
  barDate: handleBarDateChange,
  updateProgress: handleProgressUpdate,
  allowChangeTaskDate: () => true,
  addRootTask: () => {},
  addSubTask: () => {},
  removeTask: () => {},
  editTask: () => {},
  resize: (width) => {
    // 这里的 resize 事件如果组件不支持，我们可以移除，改为通过 watch ganttRef 实现
  }
})
const dataConfig = ref({
  queryStartDate: dayjs().subtract(2, 'week').format('YYYY-MM-DD'),
  queryEndDate: dayjs().add(6, 'week').format('YYYY-MM-DD'),
  dataSource: [],
  dependencies: [],
  mapFields: {
    id: 'id',
    parentId: 'parent_id',
    task: 'title',
    priority: 'priority',
    startdate: 'start_date',
    enddate: 'end_date',
    takestime: 'duration',
    progress: 'progress'
  },
  taskHeaders: [
    { title: '任务名称', width: 200, property: 'task', show: true },
    { title: '优先级', width: 80, property: 'priority', show: true },
    { title: '开始时间', width: 100, property: 'startdate', show: true },
    { title: '结束时间', width: 100, property: 'enddate', show: true },
    { title: '进度', width: 60, property: 'progress', show: true }
  ]
})

// 恢复列宽配置
try {
  const savedWidths = localStorage.getItem('gantt-column-widths')
  if (savedWidths) {
    const widths = JSON.parse(savedWidths)
    dataConfig.value.taskHeaders.forEach(h => {
      if (widths[h.property]) {
        h.width = widths[h.property]
      }
    })
  }
} catch (e) {
  console.error('Failed to restore column widths', e)
}

// 监听并保存列宽配置
watch(() => dataConfig.value.taskHeaders, (newHeaders) => {
  const widths = {}
  newHeaders.forEach(h => {
    widths[h.property] = h.width
  })
  localStorage.setItem('gantt-column-widths', JSON.stringify(widths))
}, { deep: true })

// 获取任务数据
const fetchData = async (startDate, endDate) => {
  try {
    const res = await api.get(`/tasks?project_id=${props.projectId}&fetch_all=true`)
    const tasks = res.data

    // 保存任务列表用于依赖管理
    taskList.value = tasks.map(t => ({ id: t.id, title: t.title }))

    // 转换数据格式
    const formattedTasks = tasks.map(task => ({
      id: String(task.id),
      parent_id: task.parent_id ? String(task.parent_id) : '0',
      title: task.title,
      priority: task.priority || 'medium',
      start_date: task.start_date ? `${task.start_date} 08:00:00` : null,
      end_date: task.end_date ? `${task.end_date} 18:00:00` : null,
      progress: String((task.progress || 0) / 100),
      duration: null
    })).filter(t => t.start_date && t.end_date)

    // 获取依赖关系
    const ganttRes = await api.get(`/tasks/gantt-data?project_id=${props.projectId}`)
    const links = ganttRes.data.links || []

    // 保存原始依赖关系
    rawLinks.value = links

    const formattedLinks = links.map(link => ({
      sourceTaskId: String(link.source),
      targetTaskId: String(link.target),
      type: getLinkType(link.type)
    }))

    dataConfig.value.dataSource = formattedTasks
    dataConfig.value.dependencies = formattedLinks
  } catch (error) {
    console.error('Failed to fetch gantt data', error)
    ElMessage.error('加载甘特图数据失败')
  }
}

// 转换依赖类型
const getLinkType = (type) => {
  const typeMap = {
    '0': LinkType.FINISH_TO_START,
    '1': LinkType.START_TO_START,
    '2': LinkType.FINISH_TO_FINISH,
    '3': LinkType.START_TO_FINISH
  }
  return typeMap[String(type)] || LinkType.FINISH_TO_START
}

// 创建依赖关系
const createLink = async () => {
  if (!linkForm.source || !linkForm.target) {
    ElMessage.warning('请选择前置任务和后续任务')
    return
  }
  if (linkForm.source === linkForm.target) {
    ElMessage.warning('前置任务和后续任务不能相同')
    return
  }
  try {
    await api.post('/tasks/links', {
      source: linkForm.source,
      target: linkForm.target,
      type: linkForm.type
    })
    ElMessage.success('依赖关系创建成功')
    linkForm.source = ''
    linkForm.target = ''
    linkForm.type = '0'
    fetchData()
  } catch (error) {
    ElMessage.error('创建依赖关系失败')
  }
}

// 删除依赖关系
const deleteLink = async (id) => {
  try {
    await api.delete(`/tasks/links/${id}`)
    ElMessage.success('依赖关系已删除')
    fetchData()
  } catch (error) {
    ElMessage.error('删除依赖关系失败')
  }
}



watch(() => props.projectId, () => {
  fetchData()
})

onMounted(async () => {
  // 恢复分隔线位置
  if (ganttRef.value) {
    try {
      const savedPercent = localStorage.getItem('gantt-pane-percent')
      if (savedPercent) {
        ganttRef.value.paneLengthPercent = parseFloat(savedPercent)
      }
      
      // 监听分隔线位置变化并保存
      watch(() => ganttRef.value?.paneLengthPercent, (newPercent) => {
        if (newPercent !== undefined) {
          localStorage.setItem('gantt-pane-percent', String(newPercent))
        }
      })
    } catch (e) {
      console.warn('Failed to restore splitter position', e)
    }
  }

  await fetchData()
  // 等待 DOM 更新后，自动滚动到今天
  setTimeout(() => {
    const jumpBtn = document.querySelector('svg.jumpToToday')
    if (jumpBtn) {
      jumpBtn.dispatchEvent(new MouseEvent('click', { bubbles: true }))
    }
    // 标记初始化完成，之后才响应用户操作
    setTimeout(() => {
      isInitialized.value = true
    }, 300)
  }, 500)
})
</script>

<style scoped>
.gantt-wrapper {
  width: 100%;
  height: 100%;
  background: white;
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.gantt-toolbar {
  padding: 10px 15px;
  border-bottom: 1px solid #eee;
  flex-shrink: 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.legend-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 5px 0;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 12px;
}

.legend-text {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
}

.legend-label {
  font-weight: 600;
  font-size: 12px;
  color: #606266;
}

.legend-desc {
  font-size: 11px;
  color: #909399;
}

.gantt-content {
  flex: 1;
  overflow: hidden;
}

/* 隐藏甘特图连线图例 */
:deep(.link-legend) {
  display: none !important;
}

.link-form {
  margin-bottom: 15px;
}
</style>
