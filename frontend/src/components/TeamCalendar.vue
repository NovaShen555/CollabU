<template>
  <div class="calendar-container">
    <el-calendar v-model="value">
      <template #date-cell="{ data }">
        <div class="date-cell" :class="{ 'has-events': getEvents(data.day).length > 0 }">
          <p class="day-number">{{ data.day.split('-').slice(1).join('-') }}</p>
          <div class="events">
            <div
              v-for="event in getEvents(data.day)"
              :key="event.id"
              class="event-bar"
              :class="[
                event.isPlaceholder ? 'placeholder' : `type-${event.type}`,
                {
                  'is-start': !event.isPlaceholder && event.startDate === data.day,
                  'is-end': !event.isPlaceholder && event.endDate === data.day
                }
              ]"
              @click.stop="!event.isPlaceholder && handleEventClick(event)"
            >
              <span v-if="!event.isPlaceholder && shouldShowTitle(event, data.day)" class="event-title">{{ event.title }}</span>
            </div>
          </div>
        </div>
      </template>
    </el-calendar>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api'

const router = useRouter()

const props = defineProps({
  teamId: {
    type: String,
    required: true
  }
})

const value = ref(new Date())
const events = ref([])

// 为每个事件分配固定的行号
const eventSlots = computed(() => {
  const slots = new Map() // eventId -> slotIndex
  const sortedEvents = [...events.value]
    .filter(e => e.startDate && e.endDate)
    .sort((a, b) => a.startDate.localeCompare(b.startDate) || a.id - b.id)

  // 记录每个slot的结束日期
  const slotEndDates = []

  for (const event of sortedEvents) {
    // 找到第一个可用的slot（该slot的结束日期早于当前事件的开始日期）
    let slotIndex = slotEndDates.findIndex(endDate => endDate < event.startDate)
    if (slotIndex === -1) {
      slotIndex = slotEndDates.length
      slotEndDates.push(event.endDate)
    } else {
      slotEndDates[slotIndex] = event.endDate
    }
    slots.set(event.id, slotIndex)
  }

  return slots
})

const getType = (status, priority) => {
  if (status === 'completed') return 'success'
  if (status === 'archived') return 'info'
  
  const map = {
    high: 'danger',
    medium: 'warning',
    low: 'primary' // Use primary for low priority instead of info for better visibility
  }
  return map[priority] || 'primary'
}

const fetchEvents = async () => {
  if (!props.teamId) return

  try {
     const res = await api.get(`/teams/${props.teamId}/tasks`)
     events.value = res.data.map(task => ({
       id: task.id,
       title: task.title,
       startDate: task.start_date,
       endDate: task.end_date,
       projectId: task.project_id,
       type: getType(task.status, task.priority)
     }))
  } catch (e) {
    console.error(e)
  }
}

const getEvents = (date) => {
  // 获取当天的事件
  const dayEvents = events.value
    .filter(e => e.startDate && e.endDate && date >= e.startDate && date <= e.endDate)

  if (dayEvents.length === 0) return []

  // 找出当天事件的最大slot
  const maxSlot = Math.max(...dayEvents.map(e => eventSlots.value.get(e.id) || 0))

  // 创建带占位符的数组
  const result = []
  for (let i = 0; i <= maxSlot; i++) {
    const event = dayEvents.find(e => eventSlots.value.get(e.id) === i)
    if (event) {
      result.push(event)
    } else {
      // 添加占位符
      result.push({ id: `placeholder-${i}`, isPlaceholder: true })
    }
  }

  return result
}

const shouldShowTitle = (event, date) => {
  return event.startDate === date || new Date(date).getDay() === 0
}

const handleEventClick = (event) => {
  router.push({
    path: `/projects/${event.projectId}`,
    query: { taskId: event.id }
  })
}

watch(() => props.teamId, () => {
  fetchEvents()
})

onMounted(() => {
  fetchEvents()
})
</script>

<style scoped>
.calendar-container {
  padding: 20px;
  height: 100%;
  box-sizing: border-box;
  overflow: auto;
}
:deep(.el-calendar) {
  /* height: 100%; Remove fixed height */
  display: flex;
  flex-direction: column;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
}
:deep(.el-calendar__body) {
  flex: 1;
  overflow: auto;
  padding: 12px 20px;
}
:deep(.el-calendar-table) {
  height: 100%;
}
:deep(.el-calendar-table__row) {
  /* height: 16.66%;  Remove fixed height to allow natural flow if needed, or keep if we want strict grid */
  height: 100px; /* Use min-height or fixed px to avoid percentage rounding issues if container is not perfect */
}
:deep(.el-calendar-day) {
  height: 100px !important;
  display: flex;
  flex-direction: column;
  padding: 0 !important;
}
.date-cell {
  height: 100%;
  display: flex;
  flex-direction: column;
}
.day-number {
  margin: 0;
  text-align: right;
  font-size: 12px;
  color: #606266;
  padding: 8px; /* Move padding here */
}
.events {
  flex: 1;
  overflow-y: auto;
  margin-top: 2px;
  display: flex;
  flex-direction: column;
  gap: 2px;
  /* Hide scrollbar for Chrome, Safari and Opera */
  &::-webkit-scrollbar {
    display: none;
  }
  /* Hide scrollbar for IE, Edge and Firefox */
  -ms-overflow-style: none;  /* IE and Edge */
  scrollbar-width: none;  /* Firefox */
}
.event-bar {
  height: 20px;
  line-height: 20px;
  font-size: 12px;
  color: white;
  padding: 0 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  cursor: pointer;
  background-color: #409EFF; /* Default */
  margin: 0 -1px; /* Overlap borders slightly */
  position: relative;
  z-index: 1;
}

.event-bar.placeholder {
  background-color: transparent;
  cursor: default;
}

/* Rounded corners for start and end */
.event-bar.is-start {
  border-top-left-radius: 4px;
  border-bottom-left-radius: 4px;
  margin-left: 2px;
}
.event-bar.is-end {
  border-top-right-radius: 4px;
  border-bottom-right-radius: 4px;
  margin-right: 2px;
}

/* Colors */
.type-danger {
  background-color: #F56C6C;
}
.type-warning {
  background-color: #E6A23C;
}
.type-primary {
  background-color: #409EFF;
}
.type-success {
  background-color: #67C23A;
}
.type-info {
  background-color: #909399;
}

.event-title {
  padding-left: 2px;
}
</style>
