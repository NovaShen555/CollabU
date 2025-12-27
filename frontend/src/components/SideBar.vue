<template>
  <aside :class="['sidebar', { collapsed }]" :style="sidebarStyle">
    <div class="sidebar-header">
      <div class="header-left">
        <el-tooltip v-if="!isTeams" :content="isProjectDetails ? '返回团队' : '返回首页'" placement="right">
          <el-button circle size="small" class="back-btn" :icon="ArrowLeft" @click="handleBack" />
        </el-tooltip>
        <div class="title" v-show="!collapsed">{{ isTeamDetails ? '团队' : (isProjectDetails ? '项目' : '导航') }}</div>
      </div>
      <el-tooltip :content="collapsed ? '展开侧边栏' : '收起侧边栏'" placement="left">
        <el-button circle size="small" :icon="collapsed ? Expand : Fold" @click="toggleCollapsed" />
      </el-tooltip>
    </div>
    <div class="sidebar-content">
      <template v-if="isTeamDetails">
        <div class="team-card" v-if="teamInfo && !collapsed">
          <div class="team-line">
            <span class="team-name">{{ teamInfo.name }}</span>
            <el-tag size="small" effect="plain" class="team-code" @click="copyInviteCode">
              {{ teamInfo.invite_code }}
            </el-tag>
          </div>
          <div class="team-desc" :title="teamInfo.description || '暂无描述'">
            {{ teamInfo.description || '暂无描述' }}
          </div>
        </div>
        <el-menu
          :default-active="activeTeamTab"
          class="nav-menu"
          :collapse="collapsed"
          :collapse-transition="false"
        >
          <el-menu-item index="action-create" class="menu-action-item create" @click="openCreateProject">
            <el-icon><Plus /></el-icon>
            <span>新建项目</span>
          </el-menu-item>
          <el-menu-item index="action-leave" class="menu-action-item leave" @click="leaveTeam">
            <el-icon><SwitchButton /></el-icon>
            <span>退出团队</span>
          </el-menu-item>
          <el-menu-item index="projects" @click="selectTeamTab('projects')" title="项目列表">
            <el-icon><List /></el-icon>
            <span>项目列表</span>
          </el-menu-item>
          <el-menu-item index="members" @click="selectTeamTab('members')" title="成员列表">
            <el-icon><UserFilled /></el-icon>
            <span>成员列表</span>
          </el-menu-item>
          <el-menu-item index="calendar" @click="selectTeamTab('calendar')" title="团队日程">
            <el-icon><Calendar /></el-icon>
            <span>团队日程</span>
          </el-menu-item>
          <el-menu-item index="resources" @click="selectTeamTab('resources')" title="资源分享">
            <el-icon><Link /></el-icon>
            <span>资源分享</span>
          </el-menu-item>
          <el-menu-item index="timeline" @click="selectTeamTab('timeline')" title="成果记录">
            <el-icon><Timer /></el-icon>
            <span>成果记录</span>
          </el-menu-item>
          <el-menu-item index="learning" @click="selectTeamTab('learning')" title="学习进度">
            <el-icon><DataLine /></el-icon>
            <span>学习进度</span>
          </el-menu-item>
          <el-menu-item index="chat" @click="selectTeamTab('chat')" title="在线聊天">
            <el-icon><ChatDotRound /></el-icon>
            <span>在线聊天</span>
          </el-menu-item>
        </el-menu>
      </template>
      <template v-else-if="isProjectDetails">
        <div class="project-card" v-if="projectInfo && !collapsed">
          <div class="team-line">
            <span class="team-name">{{ projectInfo.name }}</span>
            <el-tag v-if="projectInfo.status !== 'planning'" size="small" :type="getStatusType(projectInfo.status)">{{ getStatusText(projectInfo.status) }}</el-tag>
          </div>
          <div class="desc-title">项目描述</div>
          <div class="team-desc" :title="projectInfo.description || '暂无描述'">
            {{ projectInfo.description || '暂无描述' }}
          </div>
        </div>
        <el-menu
          :default-active="activePath"
          class="nav-menu"
          :collapse="collapsed"
          :collapse-transition="false"
          @select="handleSelect"
        >
          <el-menu-item index="action-task-create" class="menu-action-item create" @click="openCreateTask">
            <el-icon><Plus /></el-icon>
            <span>新建任务</span>
          </el-menu-item>
          <el-menu-item index="action-toggle-view" class="menu-action-item view" @click="toggleProjectView">
            <el-icon><Refresh /></el-icon>
            <span>切换视图</span>
          </el-menu-item>
        </el-menu>
      </template>
      <template v-else>
        <el-menu
          :default-active="activePath"
          class="nav-menu"
          :collapse="collapsed"
          :collapse-transition="false"
          @select="handleSelect"
        >
          <el-menu-item index="/teams">
            <el-icon><document /></el-icon>
            <span>团队</span>
          </el-menu-item>
          <el-menu-item index="/profile">
            <el-icon><user /></el-icon>
            <span>个人资料</span>
          </el-menu-item>
        </el-menu>
      </template>
    </div>
  </aside>
</template>
     

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Document, User, Menu, Fold, Expand, UserFilled, List, Calendar, Link, ChatDotRound, ArrowLeft, Plus, SwitchButton, Refresh, Timer, DataLine } from '@element-plus/icons-vue'
import TeamChat from './TeamChat.vue'
import api from '../api'
import { ElMessage } from 'element-plus'

const router = useRouter()
const route = useRoute()

const collapsed = ref(false)
const teamInfo = ref(null)
const activeTeamTab = ref('')

onMounted(() => {
  try {
    const saved = localStorage.getItem('sidebar-collapsed')
    collapsed.value = saved === '1'
  } catch {}
  try {
    document.documentElement.style.setProperty('--sidebar-width', collapsed.value ? '64px' : '260px')
  } catch {}
  initContext()
})

watch(collapsed, (v) => {
  try {
    localStorage.setItem('sidebar-collapsed', v ? '1' : '0')
  } catch {}
  try {
    document.documentElement.style.setProperty('--sidebar-width', v ? '64px' : '260px')
  } catch {}
})

const activePath = computed(() => route.path)

const handleSelect = (index) => {
  router.push(index)
}

const handleBack = () => {
  if (isProjectDetails.value && projectInfo.value) {
    // 从项目页返回团队页
    router.push({ name: 'TeamDetails', params: { teamId: projectInfo.value.team_id }, query: { tab: 'projects' } })
  } else if (isTeamDetails.value) {
    // 从团队页返回团队列表
    router.push('/teams')
  } else {
    // 其他情况返回上一页
    router.back()
  }
}

const toggleCollapsed = () => {
  collapsed.value = !collapsed.value
}

const headerHeight = 60
const sidebarWidth = 260
const collapsedWidth = 64

const sidebarStyle = computed(() => ({
  top: headerHeight + 'px',
  width: (collapsed.value ? collapsedWidth : sidebarWidth) + 'px'
}))

const isTeamDetails = computed(() => route.name === 'TeamDetails')
const isTeams = computed(() => route.name === 'Teams')
const teamId = computed(() => route.params.teamId)
const isProjectDetails = computed(() => route.name === 'ProjectDetails')
const projectId = computed(() => route.params.projectId)
const projectInfo = ref(null)
const projectView = computed(() => {
  const v = route.query.view
  return (typeof v === 'string' ? v : localStorage.getItem('projectView')) || 'list'
})

const initContext = async () => {
  if (isTeamDetails.value && teamId.value) {
    try {
      const res = await api.get(`/teams/${teamId.value}`)
      teamInfo.value = res.data
    } catch (e) {
      teamInfo.value = null
    }
    activeTeamTab.value = route.query.tab || ''
  } else {
    teamInfo.value = null
  }
  if (isProjectDetails.value && projectId.value) {
    try {
      const res = await api.get(`/projects/${projectId.value}`)
      projectInfo.value = res.data
    } catch (e) {
      projectInfo.value = null
    }
  } else {
    projectInfo.value = null
  }
}

watch(() => route.fullPath, () => {
  initContext()
})

const selectTeamTab = (tab) => {
  activeTeamTab.value = tab
  router.push({ name: 'TeamDetails', params: { teamId: teamId.value }, query: { tab } })
}

const getStatusType = (status) => {
  const map = { planning: 'info', in_progress: 'primary', completed: 'success', archived: 'warning' }
  return map[status] || 'info'
}
const getStatusText = (status) => {
  const map = { planning: '规划中', in_progress: '进行中', completed: '已完成', archived: '已归档' }
  return map[status] || status
}

const copyInviteCode = () => {
  if (teamInfo.value && teamInfo.value.invite_code) {
    navigator.clipboard.writeText(teamInfo.value.invite_code)
    ElMessage.success('邀请码已复制')
  }
}

const openCreateProject = () => {
  router.push({ name: 'TeamDetails', params: { teamId: teamId.value }, query: { tab: 'projects', action: 'create' } })
}

const leaveTeam = async () => {
  if (!teamId.value) return
  try {
    await api.post(`/teams/${teamId.value}/leave`)
    ElMessage.success('已退出团队')
    router.push('/teams')
  } catch (error) {
    ElMessage.error('操作失败')
  }
}

const openCreateTask = () => {
  if (!projectId.value) return
  router.push({ name: 'ProjectDetails', params: { projectId: projectId.value }, query: { action: 'create_task', view: projectView.value } })
}

const toggleProjectView = () => {
  if (!projectId.value) return
  const next = projectView.value === 'gantt' ? 'list' : 'gantt'
  router.push({ name: 'ProjectDetails', params: { projectId: projectId.value }, query: { view: next } })
}
</script>

<style scoped>
.sidebar {
  position: fixed;
  left: 0;
  bottom: 0;
  background: #fff;
  border-right: 1px solid #ebeef5;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
  display: flex;
  flex-direction: column;
  height: calc(100vh - 60px);
  z-index: 999;
  transition: width 0.2s ease;
}
.sidebar-header {
  height: 48px;
  display: flex;
  align-items: center;
  padding: 0 12px;
  border-bottom: 1px solid #f0f0f0;
  justify-content: space-between;
  box-sizing: border-box;
  min-width: 0;
}
.sidebar.collapsed .sidebar-header {
  padding: 0 4px;
}
.header-left {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
}
.sidebar.collapsed .header-left {
  gap: 4px;
}
.title {
  font-weight: 600;
  color: #606266;
  font-size: 14px;
}
.sidebar-content {
  flex: 1;
  overflow: auto;
  padding: 8px 0;
}
.nav-menu {
  border-right: none;
}

.back-btn {
  margin-right: 4px;
}
.team-actions {
  display: flex;
  gap: 8px;
  padding: 0 12px 8px;
}
.sidebar.collapsed .team-actions {
  justify-content: center;
}
.menu-action-item.create {
  --item-color: #409EFF;
  color: var(--item-color);
}
.menu-action-item.leave {
  --item-color: #F56C6C;
  color: var(--item-color);
}
.menu-action-item.view {
  --item-color: #67C23A;
  color: var(--item-color);
}

.team-card {
  margin: 8px 12px 12px;
  padding: 10px 12px;
  background: #f8f9fb;
  border: 1px solid #eef0f4;
  border-radius: 8px;
}
.project-card {
  margin: 8px 12px 12px;
  padding: 10px 12px;
  background: #f8f9fb;
  border: 1px solid #eef0f4;
  border-radius: 8px;
}
.team-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 6px;
}
.team-name {
  font-weight: 600;
  color: #303133;
  font-size: 14px;
}
.team-code {
  cursor: pointer;
}
.desc-title {
  font-size: 12px;
  color: #909399;
  margin: 6px 0;
}
.team-desc {
  color: #606266;
  font-size: 12px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
