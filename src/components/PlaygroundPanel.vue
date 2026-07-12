<template>
  <div class="pg-root">
    <!-- 顶栏 -->
    <header class="pg-header">
      <div class="pg-header-left">
        <span class="pg-badge">LAB</span>
        <span class="pg-title">SpringAI Playground</span>
        <span class="pg-sub">InterviewAgent Graph · WebSocket + RAG</span>
      </div>
      <div class="pg-header-right">
        <span class="pg-conn" :class="{ on: connected }">{{ connected ? 'WS 已连接' : '未连接' }}</span>
        <code class="pg-url">{{ wsUrl }}</code>
      </div>
    </header>

    <div class="pg-body">
      <!-- 左侧：实验配置 -->
      <aside class="pg-config">
        <section class="pg-section">
          <h3 class="pg-section-title">Graph 流水线</h3>
          <div class="pg-pipeline">
            <div
              v-for="(st, i) in stepperItems"
              :key="i"
              class="pg-pipe-node"
              :class="{ done: st.done, active: st.active }"
            >
              <div class="pg-pipe-dot">{{ i + 1 }}</div>
              <div class="pg-pipe-label">{{ st.label }}</div>
            </div>
          </div>
        </section>

        <section class="pg-section">
          <h3 class="pg-section-title">会话参数</h3>
          <label class="pg-label">userId</label>
          <input v-model="userId" class="pg-input mono" />
          <label class="pg-label">WebSocket Base</label>
          <input v-model="wsUrl" class="pg-input mono" />
        </section>

        <section class="pg-section">
          <h3 class="pg-section-title">RAG 题库上传</h3>
          <p class="pg-hint">POST /upload/question-bank · BM25 内存索引</p>
          <input type="file" accept=".md,.txt,.markdown" class="pg-file" @change="onFilePick" />
          <button class="pg-btn secondary" :disabled="!pickedFile || uploading" @click="uploadBank">
            {{ uploading ? '上传中…' : '上传题库' }}
          </button>
          <pre v-if="uploadResult" class="pg-upload-result">{{ uploadResult }}</pre>
        </section>

        <section class="pg-section">
          <h3 class="pg-section-title">启动 Graph</h3>
          <label class="pg-label">JD</label>
          <textarea v-model="jd" class="pg-textarea mono" rows="4" placeholder="职位描述…" />
          <label class="pg-label">Resume</label>
          <textarea v-model="resume" class="pg-textarea mono" rows="4" placeholder="简历摘要…" />
          <button class="pg-btn primary" :disabled="!canStart || stage === 'connecting'" @click="onStart">
            {{ stage === 'connecting' ? '连接中…' : 'start_interview →' }}
          </button>
          <button v-if="stage !== 'setup'" class="pg-btn ghost" @click="restart">重置实验</button>
          <p v-if="connectError" class="pg-error">{{ connectError }}</p>
        </section>
      </aside>

      <!-- 中间：对话区 -->
      <main class="pg-main">
        <div v-if="stage === 'setup' || stage === 'connecting'" class="pg-empty">
          <p class="pg-empty-title">InterviewAgent StateGraph</p>
          <p class="pg-empty-desc">配置左侧参数后点击 start_interview，Graph 将通过 WebSocket 推送 stage_change / question / score / report。</p>
        </div>

        <div v-else ref="transcriptRef" class="pg-transcript">
          <div v-for="m in messages" :key="m.id" class="pg-msg" :class="'pg-msg-' + m.kind">
            <template v-if="m.kind === 'system'">
              <span class="pg-msg-tag">stage</span>
              <code v-if="m.nodeLabel" class="pg-node-key">{{ m.nodeLabel }}</code>
              {{ m.text }}
            </template>
            <template v-else-if="m.kind === 'question'">
              <span class="pg-msg-tag">question #{{ m.num }}</span>
              <div>{{ m.text }}</div>
            </template>
            <template v-else-if="m.kind === 'answer'">
              <span class="pg-msg-tag">answer</span>
              <div>{{ m.text }}</div>
            </template>
            <template v-else-if="m.kind === 'score'">
              <span class="pg-msg-tag">score {{ m.score }}/100</span>
              <div>{{ m.feedback }}</div>
            </template>
            <template v-else-if="m.kind === 'error'">
              <span class="pg-msg-tag err">error</span> {{ m.text }}
            </template>
          </div>
        </div>

        <div v-if="stage === 'live'" class="pg-input-bar">
          <textarea
            v-model="answerText"
            class="pg-answer-input"
            placeholder="type: answer →"
            @keydown.enter.exact.prevent="sendAnswer"
          />
          <button class="pg-btn primary" :disabled="!canSend" @click="sendAnswer">answer</button>
          <button class="pg-btn ghost" @click="quitInterview">quit</button>
        </div>

        <div v-if="stage === 'report'" class="pg-report">
          <h2>evaluation 输出 (Markdown)</h2>
          <pre class="pg-report-md">{{ reportMd }}</pre>
          <button class="pg-btn ghost" @click="restart">新实验</button>
        </div>

        <div v-if="stage === 'ended'" class="pg-empty">
          <p>interview_complete</p>
          <button class="pg-btn ghost" @click="restart">新实验</button>
        </div>
      </main>

      <!-- 右侧：事件日志 -->
      <aside class="pg-log">
        <div class="pg-log-header">
          <span>Event Log</span>
          <button class="pg-btn ghost sm" @click="clearLog">清空</button>
        </div>
        <div class="pg-log-list">
          <div v-for="e in eventLog" :key="e.id" class="pg-log-item" :class="'dir-' + e.direction">
            <span class="pg-log-ts">{{ e.ts }}</span>
            <span class="pg-log-type">{{ e.direction }} · {{ e.type }}</span>
            <pre class="pg-log-json">{{ formatJson(e.payload) }}</pre>
          </div>
          <p v-if="!eventLog.length" class="pg-log-empty">WebSocket 消息将显示在此</p>
        </div>
      </aside>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'
import { useInterviewWebSocket } from '../composables/useInterviewWebSocket.js'

const props = defineProps({
  defaultWsUrl: { type: String, default: '' }
})

const {
  stage, jd, resume, userId, wsUrl, connectError, messages, eventLog,
  waitingForAnswer, answerText, reportMd, connected,
  canStart, canSend, stepperItems, onStart, sendAnswer, quitInterview, restart,
  httpBase
} = useInterviewWebSocket(
  props.defaultWsUrl || import.meta.env.VITE_PLAYGROUND_WS_URL || 'ws://localhost:8087',
  { systemConnectText: 'connected → 发送 start_interview { jd, resume }' }
)

const transcriptRef = ref(null)
const pickedFile = ref(null)
const uploading = ref(false)
const uploadResult = ref('')

watch(messages, async () => {
  await nextTick()
  if (transcriptRef.value) transcriptRef.value.scrollTop = transcriptRef.value.scrollHeight
}, { deep: true })

function onFilePick(ev) {
  pickedFile.value = ev.target.files?.[0] || null
  uploadResult.value = ''
}

async function uploadBank() {
  if (!pickedFile.value) return
  uploading.value = true
  uploadResult.value = ''
  try {
    const form = new FormData()
    form.append('file', pickedFile.value)
    const url = `${httpBase.value}/upload/question-bank?userId=${encodeURIComponent(userId.value)}`
    const res = await fetch(url, { method: 'POST', body: form })
    const data = await res.json()
    uploadResult.value = JSON.stringify(data, null, 2)
  } catch (err) {
    uploadResult.value = '上传失败: ' + (err.message || err)
  } finally {
    uploading.value = false
  }
}

function formatJson(payload) {
  if (payload == null) return ''
  if (typeof payload === 'string') return payload
  try { return JSON.stringify(payload, null, 2) } catch { return String(payload) }
}

function clearLog() {
  eventLog.value = []
}
</script>

<style scoped>
.pg-root {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #0f1419;
  color: #e2e8f0;
  font-family: 'SF Mono', 'Menlo', 'PingFang SC', monospace;
  font-size: 13px;
}
.pg-header {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px;
  border-bottom: 1px solid #1e293b;
  background: #111827;
}
.pg-header-left { display: flex; align-items: center; gap: 10px; }
.pg-badge {
  background: #14b8a6;
  color: #042f2e;
  font-size: 10px;
  font-weight: 700;
  padding: 2px 6px;
  border-radius: 4px;
}
.pg-title { font-weight: 700; color: #f8fafc; font-size: 14px; }
.pg-sub { color: #64748b; font-size: 12px; }
.pg-header-right { display: flex; align-items: center; gap: 12px; }
.pg-conn { font-size: 11px; color: #64748b; }
.pg-conn.on { color: #34d399; }
.pg-url { font-size: 11px; color: #475569; max-width: 280px; overflow: hidden; text-overflow: ellipsis; }

.pg-body { flex: 1; display: flex; overflow: hidden; min-height: 0; }

.pg-config {
  width: 280px;
  flex-shrink: 0;
  overflow-y: auto;
  border-right: 1px solid #1e293b;
  padding: 12px;
  background: #0c1017;
}
.pg-section { margin-bottom: 20px; }
.pg-section-title {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #64748b;
  margin: 0 0 10px;
}
.pg-pipeline { display: flex; flex-direction: column; gap: 6px; }
.pg-pipe-node {
  display: flex;
  align-items: center;
  gap: 8px;
  opacity: 0.4;
}
.pg-pipe-node.done { opacity: 0.7; }
.pg-pipe-node.active { opacity: 1; }
.pg-pipe-node.active .pg-pipe-dot { background: #14b8a6; color: #042f2e; }
.pg-pipe-node.done .pg-pipe-dot { background: #334155; color: #94a3b8; }
.pg-pipe-dot {
  width: 20px; height: 20px; border-radius: 4px;
  background: #1e293b; color: #64748b;
  display: flex; align-items: center; justify-content: center;
  font-size: 10px; font-weight: 700;
}
.pg-pipe-label { font-size: 12px; color: #94a3b8; }

.pg-label { display: block; font-size: 11px; color: #64748b; margin: 8px 0 4px; }
.pg-input, .pg-textarea {
  width: 100%;
  box-sizing: border-box;
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 6px;
  color: #e2e8f0;
  padding: 8px;
  font-size: 12px;
}
.pg-textarea { resize: vertical; min-height: 72px; }
.pg-hint { font-size: 11px; color: #475569; margin: 0 0 8px; }
.pg-file { font-size: 11px; color: #94a3b8; width: 100%; margin-bottom: 8px; }
.pg-upload-result {
  margin-top: 8px;
  padding: 8px;
  background: #1e293b;
  border-radius: 6px;
  font-size: 10px;
  overflow: auto;
  max-height: 120px;
  color: #34d399;
}

.pg-btn {
  display: block;
  width: 100%;
  margin-top: 8px;
  padding: 8px 12px;
  border-radius: 6px;
  border: none;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  font-family: inherit;
}
.pg-btn.primary { background: #14b8a6; color: #042f2e; }
.pg-btn.primary:disabled { opacity: 0.4; cursor: not-allowed; }
.pg-btn.secondary { background: #1e3a5f; color: #93c5fd; }
.pg-btn.secondary:disabled { opacity: 0.4; cursor: not-allowed; }
.pg-btn.ghost { background: transparent; color: #64748b; border: 1px solid #334155; }
.pg-btn.sm { width: auto; padding: 4px 8px; margin: 0; font-size: 10px; }
.pg-error { color: #f87171; font-size: 11px; margin-top: 8px; }

.pg-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  background: #0f1419;
}
.pg-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 24px;
  text-align: center;
  color: #64748b;
}
.pg-empty-title { font-size: 16px; color: #94a3b8; margin: 0 0 8px; }
.pg-empty-desc { font-size: 12px; max-width: 360px; line-height: 1.6; margin: 0; }

.pg-transcript {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.pg-msg {
  padding: 10px 12px;
  border-radius: 8px;
  background: #1e293b;
  border-left: 3px solid #334155;
  line-height: 1.5;
}
.pg-msg-answer { align-self: flex-end; background: #134e4a; border-color: #14b8a6; max-width: 85%; }
.pg-msg-question { border-color: #3b82f6; }
.pg-msg-score { border-color: #f59e0b; }
.pg-msg-error { border-color: #ef4444; }
.pg-msg-tag {
  display: inline-block;
  font-size: 10px;
  font-weight: 700;
  color: #14b8a6;
  margin-right: 8px;
  text-transform: uppercase;
}
.pg-msg-tag.err { color: #f87171; }
.pg-node-key {
  display: inline-block;
  background: #0f172a;
  padding: 1px 6px;
  border-radius: 4px;
  margin-right: 6px;
  color: #38bdf8;
  font-size: 11px;
}

.pg-input-bar {
  flex-shrink: 0;
  display: flex;
  gap: 8px;
  padding: 12px 16px;
  border-top: 1px solid #1e293b;
  align-items: flex-end;
}
.pg-answer-input {
  flex: 1;
  min-height: 40px;
  max-height: 100px;
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 6px;
  color: #e2e8f0;
  padding: 8px;
  font-family: inherit;
  font-size: 12px;
  resize: none;
}

.pg-report {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}
.pg-report h2 { font-size: 13px; color: #64748b; margin: 0 0 12px; }
.pg-report-md {
  background: #1e293b;
  padding: 16px;
  border-radius: 8px;
  white-space: pre-wrap;
  font-size: 12px;
  line-height: 1.6;
  color: #cbd5e1;
}

.pg-log {
  width: 300px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  border-left: 1px solid #1e293b;
  background: #0c1017;
}
.pg-log-header {
  flex-shrink: 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 12px;
  border-bottom: 1px solid #1e293b;
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.pg-log-list { flex: 1; overflow-y: auto; padding: 8px; }
.pg-log-item {
  margin-bottom: 8px;
  padding: 8px;
  background: #111827;
  border-radius: 6px;
  border-left: 2px solid #334155;
}
.pg-log-item.dir-in { border-left-color: #34d399; }
.pg-log-item.dir-out { border-left-color: #60a5fa; }
.pg-log-item.dir-sys { border-left-color: #64748b; }
.pg-log-ts { font-size: 10px; color: #475569; }
.pg-log-type { font-size: 10px; color: #94a3b8; display: block; margin: 2px 0 4px; }
.pg-log-json {
  margin: 0;
  font-size: 10px;
  color: #64748b;
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 120px;
  overflow: auto;
}
.pg-log-empty { font-size: 11px; color: #475569; text-align: center; padding: 24px; }
.mono { font-family: inherit; }
</style>
