<template>
  <div class="team-details-container">
    <div v-if="loading" class="loading">
      <el-skeleton :rows="5" animated />
    </div>

    <div v-else class="content">
      <template v-if="activeTab === 'projects'">
        <div class="section-scroll">
          <div v-if="projects.length === 0" class="empty">
             <el-empty description="暂无项目，创建一个吧" />
          </div>
          <div v-else class="project-list">
            <el-card
              v-for="project in projects"
              :key="project.id"
              class="project-card"
              shadow="hover"
              @click="handleProjectClick(project.id)"
            >
              <div class="accent" :class="`accent-${project.status || 'planning'}`"></div>
              <div class="project-header">
                <div class="project-title">{{ project.name }}</div>
                <el-tag v-if="project.status !== 'planning'" :type="getStatusType(project.status)" size="small">{{ getStatusText(project.status) }}</el-tag>
              </div>
              <div class="project-meta">
                <span class="meta-item">{{ project.start_date || '-' }} 至 {{ project.end_date || '-' }}</span>
              </div>
              <div class="project-desc">{{ project.description || '暂无描述' }}</div>
              <div class="project-footer">
                <span class="created-at">创建于 {{ formatDate(project.created_at) }}</span>
                <el-button size="small" text type="primary">查看详情</el-button>
              </div>
            </el-card>
          </div>
        </div>
      </template>

      <template v-else-if="activeTab === 'members'">
        <div class="section-scroll">
          <el-table :data="members" style="width: 100%">
            <el-table-column prop="avatar" label="头像" width="80">
              <template #default="scope">
                <el-avatar :size="40" :src="scope.row.avatar">
                   {{ scope.row.nickname ? scope.row.nickname.charAt(0).toUpperCase() : (scope.row.username ? scope.row.username.charAt(0).toUpperCase() : '') }}
                </el-avatar>
              </template>
            </el-table-column>
            <el-table-column prop="username" label="用户名" />
            <el-table-column prop="nickname" label="昵称">
               <template #default="scope">{{ scope.row.nickname || '-' }}</template>
            </el-table-column>
            <el-table-column prop="role" label="角色">
              <template #default="scope">
                <el-tag :type="scope.row.role === 'creator' ? 'warning' : 'info'">
                  {{ scope.row.role === 'creator' ? '创建者' : '成员' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="joined_at" label="加入时间">
               <template #default="scope">{{ formatDate(scope.row.joined_at) }}</template>
            </el-table-column>
          </el-table>
        </div>
      </template>

      <template v-else-if="activeTab === 'calendar'">
        <div class="section-scroll">
          <TeamCalendar :teamId="teamId" />
        </div>
      </template>

      <template v-else-if="activeTab === 'resources'">
        <div class="section-scroll">
          <ResourceList :teamId="teamId" />
        </div>
      </template>

      <template v-else-if="activeTab === 'chat'">
        <div class="section-scroll">
          <TeamChat :teamId="teamId" />
        </div>
      </template>

      <template v-else-if="activeTab === 'timeline'">
        <div class="section-scroll">
          <TeamTimeline :teamId="teamId" />
        </div>
      </template>

      <template v-else-if="activeTab === 'learning'">
        <div class="section-scroll">
          <TeamLearning :teamId="teamId" :members="members" />
        </div>
      </template>
    </div>

    <!-- 创建项目弹窗 -->
    <el-dialog v-model="showCreateProjectDialog" title="新建项目" width="30%">
      <el-form :model="createProjectForm">
        <el-form-item label="项目名称" required>
          <el-input v-model="createProjectForm.name" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="createProjectForm.description" type="textarea" />
        </el-form-item>
        <el-form-item label="起止日期">
          <el-date-picker
            v-model="createProjectForm.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateProjectDialog = false">取消</el-button>
        <el-button type="primary" @click="handleCreateProject">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'
import TeamCalendar from '../components/TeamCalendar.vue'
import ResourceList from '../components/ResourceList.vue'
import TeamChat from '../components/TeamChat.vue'
import TeamTimeline from '../components/TeamTimeline.vue'
import TeamLearning from '../components/TeamLearning.vue'

const route = useRoute()
const router = useRouter()
const teamId = route.params.teamId

const loading = ref(true)
const team = ref({})
const projects = ref([])
const members = ref([])
const activeTab = ref(route.query.tab || localStorage.getItem('teamDetailTab') || 'projects')
const showCreateProjectDialog = ref(false)

const createProjectForm = reactive({
  name: '',
  description: '',
  dateRange: []
})

const fetchTeamDetails = async () => {
  loading.value = true
  try {
    const [teamRes, projectsRes, membersRes] = await Promise.all([
      api.get(`/teams/${teamId}`),
      api.get(`/projects?team_id=${teamId}`),
      api.get(`/teams/${teamId}/members`)
    ])
    team.value = teamRes.data
    projects.value = projectsRes.data
    members.value = membersRes.data
  } catch (error) {
    console.error(error)
    ElMessage.error('获取团队信息失败')
  } finally {
    loading.value = false
  }
}

const handleCreateProject = async () => {
  if (!createProjectForm.name) {
    ElMessage.warning('请输入项目名称')
    return
  }

  const payload = {
    team_id: teamId,
    name: createProjectForm.name,
    description: createProjectForm.description,
    start_date: createProjectForm.dateRange?.[0],
    end_date: createProjectForm.dateRange?.[1]
  }

  try {
    await api.post('/projects', payload)
    ElMessage.success('项目创建成功')
    showCreateProjectDialog.value = false
    createProjectForm.name = ''
    createProjectForm.description = ''
    createProjectForm.dateRange = []
    // Refresh projects
    const res = await api.get(`/projects?team_id=${teamId}`)
    projects.value = res.data
  } catch (error) {
    console.error(error)
  }
}

const handleProjectClick = (projectId) => {
  router.push(`/projects/${projectId}`)
}

const handleLeaveTeam = () => {}

const copyInviteCode = () => {
  navigator.clipboard.writeText(team.value.invite_code)
  ElMessage.success('邀请码已复制')
}

const getStatusType = (status) => {
  const map = {
    planning: 'info',
    in_progress: 'primary',
    completed: 'success',
    archived: 'warning'
  }
  return map[status] || 'info'
}

const getStatusText = (status) => {
  const map = {
    planning: '规划中',
    in_progress: '进行中',
    completed: '已完成',
    archived: '已归档'
  }
  return map[status] || status
}

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('zh-CN')
}

// 保存标签页状态
watch(activeTab, (val) => {
  localStorage.setItem('teamDetailTab', val)
})

watch(() => route.query.tab, (val) => {
  if (typeof val === 'string' && val) {
    activeTab.value = val
  }
})
watch(() => route.query.action, (val) => {
  if (val === 'create') {
    showCreateProjectDialog.value = true
  }
})
onMounted(() => {
  fetchTeamDetails()
  if (route.query.action === 'create') {
    showCreateProjectDialog.value = true
  }
})
</script>

<style scoped>
.team-details-container {
  padding: 16px;
  height: 100%;
}
.content {
  height: 100%;
  display: flex;
  flex-direction: column;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}
.title-section {
  display: flex;
  align-items: center;
  gap: 15px;
}
.back-btn {
  margin-right: 5px;
}
.actions {
  display: none;
}
.invite-code {
  cursor: pointer;
  font-size: 12px;
  padding: 4px 8px;
  border-radius: 6px;
}
.meta-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-left: 8px;
}
.description-card {
  background: #f9f9fb;
  border: 1px solid #eef0f4;
  border-radius: 8px;
  padding: 12px 16px;
  margin: 12px 0 20px;
}
.desc-title {
  font-size: 12px;
  color: #909399;
  margin-bottom: 6px;
}
.description {
  color: #606266;
}
.project-list {
  flex: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
  gap: 24px;
  margin-top: 16px;
  overflow: auto;
  grid-auto-rows: max-content;
}
.project-card {
  cursor: pointer;
  transition: transform 0.2s;
  height: auto;
  position: relative;
}
.project-card:hover {
  transform: translateY(-5px);
}
.project-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 8px;
}
.project-title {
  margin: 0;
  font-size: 1.2rem;
  line-height: 1.4;
  font-weight: 600;
}
.project-desc {
  color: #888;
  font-size: 0.9rem;
  margin-bottom: 8px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  height: 2.8em;
}
.project-meta {
  display: flex;
  gap: 8px;
  align-items: center;
  color: #909399;
  font-size: 12px;
  margin-bottom: 6px;
}
.project-footer {
  font-size: 0.8rem;
  color: #aaa;
  text-align: right;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.accent {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 3px;
  border-radius: 4px 0 0 4px;
}
.accent-planning { background: #909399; }
.accent-in_progress { background: #409EFF; }
.accent-completed { background: #67C23A; }
.accent-archived { background: #E6A23C; }
.pane-fill {
  flex: 1;
  min-height: 0;
  display: flex;
}
.section-scroll {
  flex: 1;
  min-height: 0;
  overflow: auto;
  display: flex;
  flex-direction: column;
}
</style>
