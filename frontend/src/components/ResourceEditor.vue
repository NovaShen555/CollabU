<template>
  <div class="resource-editor">
    <div class="toolbar">
      <el-button @click="$emit('cancel')">返回</el-button>
      <el-button type="primary" @click="saveResource">保存</el-button>
      <el-upload
        class="upload-btn"
        action=""
        :http-request="handleUploadFile"
        :show-file-list="false"
        :disabled="uploading"
      >
        <el-button :loading="uploading">插入附件</el-button>
      </el-upload>
    </div>
    
    <div class="editor-container">
      <el-input v-model="form.title" placeholder="标题" class="title-input" />
      
      <div class="edit-area">
        <MdEditor 
          v-model="form.content" 
          language="zh-CN"
          :toolbarsExclude="['github']"
          @onUploadImg="handleUploadImg"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, onMounted, ref } from 'vue'
import { MdEditor } from 'md-editor-v3'
import 'md-editor-v3/lib/style.css'
import api from '../api'
import { ElMessage } from 'element-plus'

const props = defineProps({
  teamId: {
    type: String,
    required: true
  },
  resourceId: {
    type: Number,
    default: null
  },
  initialData: {
    type: Object,
    default: () => ({ title: '', content: '' })
  }
})

const emit = defineEmits(['cancel', 'saved'])

const form = reactive({
  title: '',
  content: ''
})

const uploading = ref(false)

onMounted(() => {
  if (props.initialData) {
    form.title = props.initialData.title
    form.content = props.initialData.content
  }
})

const handleUploadImg = async (files, callback) => {
  const res = await Promise.all(
    files.map(file => {
      return new Promise(async (resolve, reject) => {
        const formData = new FormData()
        formData.append('file', file)
        formData.append('team_id', props.teamId)
        if (props.resourceId) {
          formData.append('resource_id', props.resourceId)
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
  if (props.resourceId) {
    formData.append('resource_id', props.resourceId)
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
    // Use the returned URL which should be UUID based
    const markdown = isImage ? `![${options.file.name}](${url}?inline=true)` : `[${options.file.name}](${url})`
    
    // Append to content
    if (form.content === undefined) form.content = ''
    form.content += '\n' + markdown + '\n'
    ElMessage.success('附件上传成功')
  } catch (error) {
    ElMessage.error('上传失败')
  } finally {
    uploading.value = false
  }
}

const saveResource = async () => {
  if (!form.title) {
    ElMessage.warning('请输入标题')
    return
  }
  
  try {
    if (props.resourceId) {
      await api.put(`/resources/${props.resourceId}`, form)
    } else {
      await api.post('/resources', {
        team_id: props.teamId,
        ...form
      })
    }
    ElMessage.success('保存成功')
    emit('saved')
  } catch (error) {
    ElMessage.error('保存失败')
  }
}
</script>

<style scoped>
.resource-editor {
  display: flex;
  flex-direction: column;
  height: 100%;
}
.toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
  align-items: center;
}
.editor-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 20px;
}
.title-input {
  font-size: 18px;
  font-weight: bold;
}
.edit-area {
  flex: 1;
  /* Make sure editor takes remaining height */
  display: flex; 
  flex-direction: column;
}
:deep(.md-editor) {
  height: 800px;
}
.upload-btn {
  display: inline-block;
}
</style>