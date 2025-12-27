<template>
  <div class="teams-container">
    <div class="header">
      <h2>我的团队</h2>
      <div class="actions">
        <el-button type="primary" @click="showCreateDialog = true">创建团队</el-button>
        <el-button @click="showJoinDialog = true">加入团队</el-button>
      </div>
    </div>

    <div v-if="loading" class="loading">
      <el-skeleton :rows="3" animated />
    </div>

    <div v-else-if="teams.length === 0" class="empty">
      <el-empty description="暂无团队，快去创建或加入一个吧！" />
    </div>

    <div v-else class="team-list">
      <el-card v-for="team in teams" :key="team.id" class="team-card" shadow="hover" @click="handleTeamClick(team.id)">
        <div class="team-info">
          <el-avatar :size="50" :src="team.avatar || 'https://cube.elemecdn.com/3/7c/3ea6beec64369c2642b92c6726f1epng.png'" />
          <div class="team-detail">
            <h3>{{ team.name }}</h3>
            <p>{{ team.description || '暂无描述' }}</p>
          </div>
        </div>
      </el-card>
    </div>

    <!-- 创建团队弹窗 -->
    <el-dialog v-model="showCreateDialog" title="创建团队" width="30%">
      <el-form :model="createForm">
        <el-form-item label="团队名称" required>
          <el-input v-model="createForm.name" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="createForm.description" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="handleCreateTeam">确定</el-button>
      </template>
    </el-dialog>

    <!-- 加入团队弹窗 -->
    <el-dialog v-model="showJoinDialog" title="加入团队" width="30%">
      <el-form :model="joinForm">
        <el-form-item label="邀请码" required>
          <el-input v-model="joinForm.invite_code" placeholder="请输入8位邀请码" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showJoinDialog = false">取消</el-button>
        <el-button type="primary" @click="handleJoinTeam">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api'
import { ElMessage } from 'element-plus'

const router = useRouter()
const teams = ref([])
const loading = ref(true)
const showCreateDialog = ref(false)
const showJoinDialog = ref(false)

const createForm = reactive({
  name: '',
  description: ''
})

const joinForm = reactive({
  invite_code: ''
})

const fetchTeams = async () => {
  loading.value = true
  try {
    const res = await api.get('/teams')
    teams.value = res.data
  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
}

const handleCreateTeam = async () => {
  if (!createForm.name) {
    ElMessage.warning('请输入团队名称')
    return
  }
  try {
    await api.post('/teams', createForm)
    ElMessage.success('创建成功')
    showCreateDialog.value = false
    createForm.name = ''
    createForm.description = ''
    fetchTeams()
  } catch (error) {
    console.error(error)
  }
}

const handleJoinTeam = async () => {
  if (!joinForm.invite_code) {
    ElMessage.warning('请输入邀请码')
    return
  }
  try {
    await api.post('/teams/join', joinForm)
    ElMessage.success('加入成功')
    showJoinDialog.value = false
    joinForm.invite_code = ''
    fetchTeams()
  } catch (error) {
    console.error(error)
  }
}

const handleTeamClick = (teamId) => {
  router.push(`/teams/${teamId}`)
}

onMounted(() => {
  fetchTeams()
})
</script>

<style scoped>
.teams-container {
  padding: 20px;
  max-width: 800px;
  margin: 0 auto;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
.team-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
}
.team-card {
  cursor: pointer;
  transition: transform 0.2s;
}
.team-card:hover {
  transform: translateY(-5px);
}
.team-info {
  display: flex;
  align-items: center;
  gap: 15px;
}
.team-detail h3 {
  margin: 0 0 5px 0;
}
.team-detail p {
  margin: 0;
  color: #666;
  font-size: 0.9em;
}
</style>
