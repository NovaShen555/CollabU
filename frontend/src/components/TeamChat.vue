<template>
  <div class="team-chat">
    <div class="chat-messages" ref="messagesContainer">
      <div v-if="messages.length === 0" class="empty-state">
        暂无消息，开始聊天吧！
      </div>
      <div 
        v-for="msg in messages" 
        :key="msg.id" 
        class="message-item"
        :class="{ 'is-me': msg.user_id === userStore.user.id }"
      >
        <el-avatar :size="40" :src="msg.avatar" class="message-avatar">
          {{ msg.nickname ? msg.nickname.charAt(0).toUpperCase() : msg.username.charAt(0).toUpperCase() }}
        </el-avatar>
        <div class="message-content-wrapper">
          <div class="message-info">
            <span class="nickname">{{ msg.nickname || msg.username }}</span>
            <span class="time">{{ formatTime(msg.created_at) }}</span>
          </div>
          <div class="message-bubble">
            <MdPreview :modelValue="msg.content" class="markdown-content" />
          </div>
        </div>
      </div>
    </div>

    <div class="chat-input-area">
      <div class="input-wrapper" ref="inputWrapper">
        <MdEditor 
          v-model="inputContent"
          language="zh-CN"
          :toolbarsExclude="['github', 'save']"
          :toolbars="[
            'bold', 'underline', 'italic', '-',
            'title', 'strikeThrough', 'sub', 'sup', 'quote', 'unorderedList', 'orderedList', '-',
            'codeRow', 'code', 'link', 'image', 'table', 'mermaid', 'katex', '-',
            'revoke', 'next', '=', 'pageFullscreen', 'fullscreen', 'preview', 'htmlPreview'
          ]"
          :preview="false"
          placeholder="输入消息 (支持 Markdown)... Ctrl+Enter 发送"
          @onUploadImg="handleUploadImg"
          class="mini-editor"
        />
        <div class="action-bar">
           <el-upload
            class="upload-btn"
            action=""
            :http-request="handleUploadFile"
            :show-file-list="false"
            :disabled="uploading"
          >
            <el-button size="small" :loading="uploading" icon="Paperclip" text>附件</el-button>
          </el-upload>
          <el-button type="primary" class="send-btn" @click="sendMessage" :disabled="!inputContent.trim()">
            发送 (Ctrl+Enter)
          </el-button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { useUserStore } from '../stores/user'
import api from '../api'
import io from 'socket.io-client'
import { MdPreview, MdEditor } from 'md-editor-v3'
import 'md-editor-v3/lib/style.css'
import { ElMessage } from 'element-plus'
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
dayjs.extend(utc)

const props = defineProps({
  teamId: {
    type: String,
    required: true
  }
})

const userStore = useUserStore()
const messages = ref([])
const inputContent = ref('')
const messagesContainer = ref(null)
const socket = ref(null)
const uploading = ref(false)
const inputWrapper = ref(null)

const formatTime = (timeStr) => {
  if (!timeStr) return ''
  // 统一按 UTC 解析，再转换到本地时区显示
  // 支持后端返回的 ISO 字符串（带或不带时区）
  const dt = dayjs.utc(timeStr).local()
  return dt.format('MM-DD HH:mm')
}

const scrollToBottom = async () => {
  await nextTick()
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  }
}

const fetchMessages = async () => {
  try {
    const res = await api.get(`/teams/${props.teamId}/messages`)
    messages.value = res.data
    scrollToBottom()
  } catch (error) {
    console.error(error)
  }
}

const initSocket = () => {
  const token = localStorage.getItem('token')
  // Use relative path '/api' is wrong for socket.io which usually needs root '/' but with path option if configured.
  // Standard socket.io client tries to connect to window.location.host
  // If backend is on 5000 and we are proxying...
  // Let's try explicit URL if in dev, or relative if proxy handles upgrade.
  // Vite proxy handles http but maybe not ws upgrade correctly without config?
  // Let's use the same logic as before: hardcode localhost:5000 for dev or use window.location.origin
  
  // Since we added proxy for /socket.io in vite.config.js, we can use relative path
  socket.value = io({
    path: '/socket.io',
    query: { token },
    transports: ['websocket', 'polling']
  })

  socket.value.on('connect', () => {
    console.log('Connected to socket')
    socket.value.emit('team:join', { token, team_id: props.teamId })
  })

  socket.value.on('team:message', (message) => {
    messages.value.push(message)
    scrollToBottom()
  })

  socket.value.on('error', (data) => {
    console.error('Socket error:', data)
    ElMessage.error(data.message)
  })
}

const sendMessage = () => {
  if (!inputContent.value.trim()) return
  
  const token = localStorage.getItem('token')
  socket.value.emit('team:message', {
    token,
    team_id: props.teamId,
    content: inputContent.value
  })
  
  inputContent.value = ''
}

const handleKeydown = (e) => {
  if (e.key === 'Enter' && e.ctrlKey) {
    if (inputWrapper.value && inputWrapper.value.contains(document.activeElement)) {
      if (inputContent.value.trim()) {
        e.preventDefault()
        sendMessage()
      }
    }
  }
}

const handleUploadImg = async (files, callback) => {
  const res = await Promise.all(
    files.map(file => {
      return new Promise(async (resolve, reject) => {
        const formData = new FormData()
        formData.append('file', file)
        formData.append('team_id', props.teamId)

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
  
  try {
    const res = await api.post('/files/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })
    
    const url = res.data.url
    const isImage = options.file.type.startsWith('image/')
    // Use inline=true for images
    const markdown = isImage ? `![${options.file.name}](${url}?inline=true)` : `[${options.file.name}](${url})`
    
    // Append to content
    inputContent.value += (inputContent.value ? '\n' : '') + markdown
    ElMessage.success('附件上传成功')
  } catch (error) {
    ElMessage.error('上传失败')
  } finally {
    uploading.value = false
  }
}

watch(() => props.teamId, () => {
  if (socket.value) {
    socket.value.disconnect()
    initSocket()
    fetchMessages()
  }
})

onMounted(() => {
  fetchMessages()
  initSocket()
  window.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  if (socket.value) {
    socket.value.disconnect()
  }
  window.removeEventListener('keydown', handleKeydown)
})
</script>

<style scoped>
.team-chat {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #f5f7fa;
  border-radius: 8px;
  overflow: hidden;
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.empty-state {
  text-align: center;
  color: #909399;
  margin-top: 50px;
}

.message-item {
  display: flex;
  gap: 12px;
  max-width: 80%;
}

.message-item.is-me {
  align-self: flex-end;
  flex-direction: row-reverse;
}

.message-content-wrapper {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.message-info {
  font-size: 12px;
  color: #909399;
}

.is-me .message-info {
  text-align: right;
}

.nickname {
  margin-right: 8px;
  font-weight: bold;
}

.is-me .nickname {
  margin-right: 0;
  margin-left: 8px;
}

.message-bubble {
  background: white;
  padding: 10px 15px;
  border-radius: 8px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.1);
  overflow: hidden;
}

.is-me .message-bubble {
  background: #ecf5ff; /* Light blue for me */
}

/* Fix markdown styles in bubble */
.markdown-content {
  background: transparent !important;
  padding: 0 !important;
}

.chat-input-area {
  background: white;
  padding: 0;
  border-top: 1px solid #e4e7ed;
  display: flex;
  flex-direction: column;
}

.input-wrapper {
  display: flex;
  flex-direction: column;
}

.mini-editor {
  height: 150px;
}

:deep(.md-editor-footer) {
  display: none;
}

.action-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 15px;
  background: #f9f9f9;
  border-top: 1px solid #eee;
}

.send-btn {
  height: auto;
  padding: 8px 20px;
}
</style>
