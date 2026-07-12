<template>
  <div style="height:100vh;width:100%;display:flex;background:#faf8f4;color:#1d1d1f;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','PingFang SC','Helvetica Neue',Arial,sans-serif;overflow:hidden;">

    <div style="flex-shrink:0;width:280px;height:100%;background:#f3efe6;border-right:1px solid rgba(0,0,0,0.08);display:flex;flex-direction:column;">
      <div style="padding:28px 24px 20px;">
        <div style="display:flex;align-items:center;gap:10px;">
          <div style="width:8px;height:8px;border-radius:50%;background:#8a6f45;"></div>
          <span style="font-size:16px;font-weight:600;letter-spacing:0.01em;">Agent 中心</span>
        </div>
        <p style="font-size:13px;color:#6e6e73;margin:10px 0 0;line-height:1.5;">选择一个 Agent，开启专属对话</p>
      </div>

      <div style="flex:1;overflow-y:auto;padding:4px 16px 16px;display:flex;flex-direction:column;gap:6px;">
        <div
          v-for="ag in agents"
          :key="ag.id"
          @click="select(ag)"
          :style="{
            display: 'flex', alignItems: 'center', gap: '12px', padding: '12px',
            borderRadius: '12px', cursor: 'pointer',
            background: selected === ag.id ? 'rgba(138,111,69,0.12)' : 'transparent'
          }"
        >
          <div :style="{
            flexShrink: 0, width: '36px', height: '36px', borderRadius: '10px',
            background: selected === ag.id ? '#8a6f45' : '#e7e0d2',
            color: selected === ag.id ? '#fff' : '#8a6f45',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: '14px', fontWeight: 700
          }">{{ ag.name.charAt(0) }}</div>
          <div style="flex:1;min-width:0;">
            <div :style="{ fontSize: '14px', fontWeight: selected === ag.id ? 700 : 600, color: '#1d1d1f', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }">{{ ag.name }}</div>
            <div style="font-size:12px;color:#6e6e73;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{{ ag.desc }}</div>
          </div>
        </div>
      </div>
    </div>

    <div style="flex:1;height:100%;overflow:hidden;display:flex;flex-direction:column;">
      <InterviewAgent
        v-if="activeAgent?.component === 'interview'"
        :key="activeAgent.id"
        :title="activeAgent.title"
        :default-ws-url="activeAgent.wsUrl"
      />
      <MyAgent
        v-else-if="activeAgent?.component === 'myagent'"
        :key="activeAgent.id"
        :title="activeAgent.title"
        :default-ws-url="activeAgent.wsUrl"
      />
      <div v-else style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;">
        <div style="width:48px;height:48px;border-radius:50%;border:1px solid rgba(0,0,0,0.1);display:flex;align-items:center;justify-content:center;font-size:20px;color:#8a6f45;">◎</div>
        <span style="font-size:17px;font-weight:600;">选择左侧的 Agent 开始对话</span>
        <span style="font-size:14px;color:#6e6e73;">每个 Agent 拥有独立的会话与连接</span>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import InterviewAgent from './components/InterviewAgent.vue'
import MyAgent from './components/MyAgent.vue'

const selected = ref(null)

const agents = [
  {
    id: 'interview',
    name: '面试模拟 Agent',
    title: 'AI 面试官',
    desc: '稳定版 · interview-agent',
    component: 'interview',
    wsUrl: import.meta.env.VITE_INTERVIEW_AGENT_WS_URL || 'ws://localhost:8085'
  },
  {
    id: 'playground',
    name: 'MyAgent',
    title: 'MyAgent · 天气助手',
    desc: 'ReactAgent · WebSocket 对话',
    component: 'myagent',
    wsUrl: import.meta.env.VITE_PLAYGROUND_WS_URL || 'ws://localhost:8087'
  }
]

const activeAgent = computed(() => agents.find(a => a.id === selected.value) || null)

function select(ag) {
  selected.value = ag.id
}
</script>
