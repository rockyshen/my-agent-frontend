<template>
  <div class="app-shell">
    <!-- Desktop sidebar -->
    <aside class="sidebar desktop-only">
      <div class="sidebar-head">
        <div class="brand-dot"></div>
        <span class="brand-title">Agent 中心</span>
        <p class="brand-desc">Interview · 记账 · Playground</p>
      </div>
      <nav class="agent-list">
        <button
          v-for="ag in agents"
          :key="ag.id"
          type="button"
          class="agent-item"
          :class="{ active: selected === ag.id }"
          @click="select(ag)"
        >
          <span class="agent-icon" :class="{ active: selected === ag.id }">{{ ag.short }}</span>
          <span class="agent-meta">
            <span class="agent-name">{{ ag.name }}</span>
            <span class="agent-desc">{{ ag.desc }}</span>
          </span>
        </button>
      </nav>
    </aside>

    <!-- Mobile bottom tabs -->
    <nav class="tabbar mobile-only">
      <button
        v-for="ag in agents"
        :key="ag.id"
        type="button"
        class="tab-item"
        :class="{ active: selected === ag.id }"
        @click="select(ag)"
      >
        <span class="tab-icon">{{ ag.short }}</span>
        <span class="tab-label">{{ ag.tabLabel }}</span>
      </button>
    </nav>

    <main class="main-panel">
      <InterviewAgent
        v-if="activeAgent?.component === 'interview'"
        :key="activeAgent.id"
        :title="activeAgent.title"
        :default-ws-url="activeAgent.wsUrl"
      />
      <EasyAccountAgent
        v-else-if="activeAgent?.component === 'easyaccount'"
        :key="activeAgent.id"
        :title="activeAgent.title"
        :default-ws-url="activeAgent.wsUrl"
        :default-http-url="activeAgent.httpUrl"
      />
      <MyAgent
        v-else-if="activeAgent?.component === 'myagent'"
        :key="activeAgent.id"
        :title="activeAgent.title"
        :default-ws-url="activeAgent.wsUrl"
      />
      <div v-else class="placeholder">
        <div class="placeholder-icon">◎</div>
        <span class="placeholder-title">选择一个 Agent</span>
        <span class="placeholder-sub">Interview · 记账 · Playground</span>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import InterviewAgent from './components/InterviewAgent.vue'
import EasyAccountAgent from './components/EasyAccountAgent.vue'
import MyAgent from './components/MyAgent.vue'

const selected = ref('easyaccount')

const agents = [
  {
    id: 'interview',
    short: '面',
    tabLabel: '面试',
    name: 'Interview Agent',
    title: 'AI 面试官',
    desc: 'interview-agent · 8085',
    component: 'interview',
    wsUrl: import.meta.env.VITE_INTERVIEW_AGENT_WS_URL || 'ws://localhost:8085'
  },
  {
    id: 'easyaccount',
    short: '账',
    tabLabel: '记账',
    name: 'EasyAccount Agent',
    title: '智能记账助手',
    desc: 'easyaccount-agent · 登录 + WS',
    component: 'easyaccount',
    wsUrl: import.meta.env.VITE_EASYACCOUNT_WS_URL || 'ws://127.0.0.1:8088',
    httpUrl: import.meta.env.VITE_EASYACCOUNT_HTTP_URL || 'http://127.0.0.1:8088'
  },
  {
    id: 'playground',
    short: 'P',
    tabLabel: 'Playground',
    name: 'SpringAI Playground',
    title: 'MyAgent · 极简对话',
    desc: 'ReactAgent · 8087',
    component: 'myagent',
    wsUrl: import.meta.env.VITE_PLAYGROUND_WS_URL || 'ws://localhost:8087'
  }
]

const activeAgent = computed(() => agents.find(a => a.id === selected.value) || null)

function select(ag) {
  selected.value = ag.id
}
</script>

<style scoped>
.app-shell {
  height: 100vh;
  width: 100%;
  display: flex;
  background: #faf8f4;
  color: #1d1d1f;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'PingFang SC', sans-serif;
  overflow: hidden;
}

.sidebar {
  flex-shrink: 0;
  width: 280px;
  height: 100%;
  background: #f3efe6;
  border-right: 1px solid rgba(0, 0, 0, 0.08);
  display: flex;
  flex-direction: column;
}

.sidebar-head { padding: 28px 24px 16px; }
.brand-dot { width: 8px; height: 8px; border-radius: 50%; background: #8a6f45; display: inline-block; margin-right: 8px; }
.brand-title { font-size: 16px; font-weight: 600; }
.brand-desc { font-size: 13px; color: #6e6e73; margin: 10px 0 0; }

.agent-list { flex: 1; overflow-y: auto; padding: 4px 16px 16px; display: flex; flex-direction: column; gap: 6px; }
.agent-item {
  display: flex; align-items: center; gap: 12px; padding: 12px; border-radius: 12px;
  border: none; background: transparent; cursor: pointer; text-align: left; width: 100%;
}
.agent-item.active { background: rgba(138, 111, 69, 0.12); }
.agent-icon {
  width: 36px; height: 36px; border-radius: 10px; background: #e7e0d2; color: #8a6f45;
  display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 700; flex-shrink: 0;
}
.agent-icon.active { background: #8a6f45; color: #fff; }
.agent-meta { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.agent-name { font-size: 14px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.agent-desc { font-size: 12px; color: #6e6e73; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.main-panel {
  flex: 1;
  min-width: 0;
  height: 100%;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.placeholder {
  flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px;
}
.placeholder-icon {
  width: 48px; height: 48px; border-radius: 50%; border: 1px solid rgba(0,0,0,0.1);
  display: flex; align-items: center; justify-content: center; color: #8a6f45; font-size: 20px;
}
.placeholder-title { font-size: 17px; font-weight: 600; }
.placeholder-sub { font-size: 14px; color: #6e6e73; }

.tabbar {
  order: 2;
  flex-shrink: 0;
  display: flex;
  border-top: 1px solid rgba(60, 60, 67, 0.12);
  background: rgba(250, 248, 244, 0.96);
  backdrop-filter: blur(10px);
  padding-bottom: env(safe-area-inset-bottom);
}

.tab-item {
  flex: 1; border: none; background: transparent; padding: 8px 4px 6px;
  display: flex; flex-direction: column; align-items: center; gap: 2px; color: #8e8e93;
}
.tab-item.active { color: #007aff; }
.tab-icon {
  width: 28px; height: 28px; border-radius: 8px; background: rgba(120,120,128,0.12);
  display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 700;
}
.tab-item.active .tab-icon { background: rgba(0, 122, 255, 0.14); color: #007aff; }
.tab-label { font-size: 11px; font-weight: 500; }

.mobile-only { display: none; }

@media (max-width: 768px) {
  .app-shell { flex-direction: column; }
  .desktop-only { display: none; }
  .mobile-only { display: flex; }
  .main-panel { order: 1; flex: 1; min-height: 0; }
}
</style>
