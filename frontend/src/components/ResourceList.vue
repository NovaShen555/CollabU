<template>
  <div class="resource-list-container">
    <div v-if="!isEditing && !currentResource" class="list-view">
      <div class="list-header">
        <el-button type="primary" @click="startCreate">新建文章</el-button>
      </div>
      
      <el-table :data="resources" style="width: 100%" v-loading="loading">
        <el-table-column prop="title" label="标题">
          <template #default="scope">
            <el-link type="primary" @click="viewResource(scope.row)">{{ scope.row.title }}</el-link>
          </template>
        </el-table-column>
        <el-table-column prop="updated_at" label="更新时间" width="180">
          <template #default="scope">{{ formatDate(scope.row.updated_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="scope">
            <el-button size="small" @click="editResource(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteResource(scope.row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <div v-else-if="currentResource && !isEditing" class="detail-view">
      <div class="detail-header">
        <el-button @click="backToList" icon="ArrowLeft">返回列表</el-button>
        <div class="detail-actions">
           <el-button type="primary" @click="editResource(currentResource)">编辑</el-button>
        </div>
      </div>
      <h1 class="resource-title">{{ currentResource.title }}</h1>
      <div class="preview-content">
        <MdPreview :modelValue="currentResource.content" language="zh-CN" />
      </div>
    </div>

    <div v-else class="editor-view">
      <ResourceEditor
        :team-id="teamId"
        :resource-id="currentResource ? currentResource.id : null"
        :initial-data="currentResource"
        @cancel="cancelEdit"
        @saved="handleSaved"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api'
import ResourceEditor from './ResourceEditor.vue'
import { MdPreview } from 'md-editor-v3'
import 'md-editor-v3/lib/style.css'
import { ElMessage, ElMessageBox } from 'element-plus'

const props = defineProps({
  teamId: {
    type: String,
    required: true
  }
})

const loading = ref(false)
const resources = ref([])
const currentResource = ref(null)
const isEditing = ref(false)

const fetchResources = async () => {
  loading.value = true
  try {
    const res = await api.get(`/resources?team_id=${props.teamId}`)
    resources.value = res.data
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const formatDate = (dateStr) => {
  return new Date(dateStr).toLocaleDateString('zh-CN')
}

const startCreate = () => {
  currentResource.value = null
  isEditing.value = true
}

const viewResource = (resource) => {
  currentResource.value = resource
  isEditing.value = false
}

const editResource = (resource) => {
  currentResource.value = resource
  isEditing.value = true
}

const cancelEdit = () => {
  if (currentResource.value && currentResource.value.id) {
    isEditing.value = false
  } else {
    // Creating canceled
    isEditing.value = false
    currentResource.value = null
  }
}

const backToList = () => {
  currentResource.value = null
  isEditing.value = false
}

const handleSaved = () => {
  isEditing.value = false
  currentResource.value = null // Back to list to refresh
  fetchResources()
}

const deleteResource = (resource) => {
  ElMessageBox.confirm('确定要删除这篇文章吗？', '警告', { type: 'warning' })
    .then(async () => {
      try {
        await api.delete(`/resources/${resource.id}`)
        ElMessage.success('删除成功')
        fetchResources()
      } catch (error) {
        ElMessage.error('删除失败')
      }
    })
    .catch(() => {})
}

onMounted(() => {
  fetchResources()
})
</script>

<style scoped>
.resource-list-container {
  padding: 20px;
  background: white;
  min-height: 400px;
}
.list-header {
  margin-bottom: 20px;
}
.detail-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 20px;
}
.resource-title {
  margin-bottom: 30px;
  border-bottom: 1px solid #eee;
  padding-bottom: 10px;
}
.preview-content {
  line-height: 1.6;
}
</style>