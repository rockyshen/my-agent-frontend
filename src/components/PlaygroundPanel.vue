<template>
  <div class="pg-root">
    <header class="pg-header">
      <div class="pg-header-left">
        <span class="pg-badge">LAB</span>
        <span class="pg-title">SpringAI Playground</span>
        <span class="pg-sub">Email Agent · StateGraph + Human-in-the-Loop</span>
      </div>
      <code class="pg-url">{{ apiBase }}</code>
    </header>

    <div class="pg-body">
      <aside class="pg-config">
        <section class="pg-section">
          <h3 class="pg-section-title">Graph 节点</h3>
          <div class="pg-pipeline">
            <div v-for="node in graphNodes" :key="node.id" class="pg-pipe-node" :class="nodeClass(node.id)">
              <div class="pg-pipe-dot">{{ node.short }}</div>
              <div class="pg-pipe-label">{{ node.label }}</div>
            </div>
          </div>
        </section>

        <section class="pg-section">
          <h3 class="pg-section-title">API</h3>
          <label class="pg-label">Base URL</label>
          <input v-model="apiBase" class="pg-input" />
          <label class="pg-label">threadId</label>
          <input v-model="threadId" class="pg-input" placeholder="start 后自动填充" />
        </section>

        <section class="pg-section">
          <h3 class="pg-section-title">1. POST /email-agent/start</h3>
          <label class="pg-label">senderEmail</label>
          <input v-model="senderEmail" class="pg-input" />
          <label class="pg-label">emailId</label>
          <input v-model="emailId" class="pg-input" />
          <label class="pg-label">emailContent</label>
          <textarea v-model="emailContent" class="pg-textarea" rows="5" />
          <button class="pg-btn primary" :disabled="loading || !emailContent.trim()" @click="startAgent">
            {{ loading ? 'Graph 运行中…' : 'start →' }}
          </button>
          <button class="pg-btn secondary" :disabled="loading" @click="runBillingDemo">test/billing 示例</button>
        </section>

        <section v-if="phase === 'review'" class="pg-section">
          <h3 class="pg-section-title">2. POST /email-agent/resume</h3>
          <label class="pg-label">editedResponse</label>
          <textarea v-model="editedResponse" class="pg-textarea" rows="6" />
          <button class="pg-btn primary" :disabled="loading" @click="resumeAgent(true)">approved → send</button>
          <button class="pg-btn ghost" :disabled="loading" @click="resumeAgent(false)">reject</button>
        </section>

        <p v-if="error" class="pg-error">{{ error }}</p>
        <button v-if="phase !== 'idle'" class="pg-btn ghost" @click="reset">重置</button>
      </aside>

      <main class="pg-main">
        <div v-if="phase === 'idle'" class="pg-empty">
          <p class="pg-empty-title">Email Agent Graph</p>
          <p class="pg-empty-desc">
            填写客户邮件后点击 start，Graph 会在 <code>human_review</code> 中断。<br />
            审核草稿回复后调用 resume 完成 send_reply。
          </p>
        </div>

        <div v-else class="pg-content">
          <div v-if="classification" class="pg-card">
            <h4>classify_intent</h4>
            <p>intent: <strong>{{ classification.intent }}</strong></p>
            <p>urgency: <strong>{{ classification.urgency }}</strong></p>
          </div>

          <div v-if="stateSnapshot?.email_content" class="pg-card">
            <h4>original email</h4>
            <pre>{{ stateSnapshot.email_content }}</pre>
          </div>

          <div v-if="stateSnapshot?.draft_response" class="pg-card highlight">
            <h4>draft_response</h4>
            <pre>{{ stateSnapshot.draft_response }}</pre>
          </div>

          <div v-if="phase === 'done'" class="pg-card success">
            <h4>send_reply 完成</h4>
            <p>status: <strong>{{ finalStatus }}</strong></p>
            <pre v-if="finalState">{{ formatJson(finalState) }}</pre>
          </div>
        </div>
      </main>

      <aside class="pg-log">
        <div class="pg-log-header">
          <span>HTTP Log</span>
          <button class="pg-btn ghost sm" @click="httpLog = []">清空</button>
        </div>
        <div class="pg-log-list">
          <div v-for="e in httpLog" :key="e.id" class="pg-log-item">
            <span class="pg-log-ts">{{ e.ts }}</span>
            <span class="pg-log-type">{{ e.method }} {{ e.path }} · {{ e.status }}</span>
            <pre class="pg-log-json">{{ e.body }}</pre>
          </div>
          <p v-if="!httpLog.length" class="pg-log-empty">API 调用记录将显示在此</p>
        </div>
      </aside>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  defaultApiBase: { type: String, default: '' }
})

const apiBase = ref(
  props.defaultApiBase
  || import.meta.env.VITE_PLAYGROUND_HTTP_URL
  || 'http://localhost:8087'
)

const graphNodes = [
  { id: 'read_email', short: '1', label: 'read_email' },
  { id: 'classify_intent', short: '2', label: 'classify_intent' },
  { id: 'search_documentation', short: '3a', label: 'search_doc' },
  { id: 'bug_tracking', short: '3b', label: 'bug_track' },
  { id: 'draft_response', short: '4', label: 'draft_response' },
  { id: 'human_review', short: '5', label: 'human_review' },
  { id: 'send_reply', short: '6', label: 'send_reply' }
]

const threadId = ref('')
const senderEmail = ref('customer@example.com')
const emailId = ref('email-' + Date.now())
const emailContent = ref('我的订阅被收费两次了！请尽快处理。')
const editedResponse = ref('')

const phase = ref('idle') // idle | review | done
const loading = ref(false)
const error = ref('')
const stateSnapshot = ref(null)
const classification = ref(null)
const finalState = ref(null)
const finalStatus = ref('')
const activeNode = ref('')
const httpLog = ref([])

function nodeClass(id) {
  if (activeNode.value === id) return 'active'
  const order = graphNodes.map(n => n.id)
  const ai = order.indexOf(activeNode.value)
  const ni = order.indexOf(id)
  if (ai >= 0 && ni >= 0 && ni < ai) return 'done'
  return ''
}

function formatJson(obj) {
  try { return JSON.stringify(obj, null, 2) } catch { return String(obj) }
}

function logHttp(method, path, status, body) {
  httpLog.value.push({
    id: httpLog.value.length,
    ts: new Date().toLocaleTimeString('zh-CN', { hour12: false }),
    method,
    path,
    status,
    body: typeof body === 'string' ? body : formatJson(body)
  })
}

async function apiCall(method, path, payload) {
  const url = apiBase.value.replace(/\/$/, '') + path
  const opts = { method, headers: { 'Content-Type': 'application/json' } }
  if (payload !== undefined) opts.body = JSON.stringify(payload)
  const res = await fetch(url, opts)
  const text = await res.text()
  let data
  try { data = JSON.parse(text) } catch { data = text }
  logHttp(method, path, res.status, data)
  if (!res.ok) throw new Error(typeof data === 'object' ? (data.message || res.statusText) : text)
  return data
}

function applyState(state) {
  stateSnapshot.value = state
  classification.value = state?.classification || null
  editedResponse.value = state?.draft_response || editedResponse.value
  activeNode.value = state?.next_node || state?.status || ''
  if (state?.status === 'waiting_for_review') phase.value = 'review'
}

async function startAgent() {
  loading.value = true
  error.value = ''
  try {
    const data = await apiCall('POST', '/email-agent/start', {
      threadId: threadId.value || null,
      emailContent: emailContent.value,
      senderEmail: senderEmail.value,
      emailId: emailId.value
    })
    threadId.value = data.threadId
    applyState(data.state)
  } catch (e) {
    error.value = e.message || String(e)
  } finally {
    loading.value = false
  }
}

async function resumeAgent(approved) {
  loading.value = true
  error.value = ''
  try {
    const data = await apiCall('POST', '/email-agent/resume', {
      threadId: threadId.value,
      approved,
      editedResponse: approved ? editedResponse.value : null
    })
    finalState.value = data.state
    finalStatus.value = data.status || data.state?.status || 'done'
    activeNode.value = 'send_reply'
    phase.value = 'done'
  } catch (e) {
    error.value = e.message || String(e)
  } finally {
    loading.value = false
  }
}

async function runBillingDemo() {
  loading.value = true
  error.value = ''
  try {
    const tid = threadId.value || 'demo-' + Date.now()
    const data = await apiCall('GET', `/email-agent/test/billing?threadId=${encodeURIComponent(tid)}`)
    threadId.value = data.threadId
    finalState.value = data.finalState
    finalStatus.value = data.status || 'sent'
    stateSnapshot.value = data.interruptedState || data.finalState
    classification.value = stateSnapshot.value?.classification || null
    editedResponse.value = stateSnapshot.value?.draft_response || ''
    activeNode.value = 'send_reply'
    phase.value = 'done'
  } catch (e) {
    error.value = e.message || String(e)
  } finally {
    loading.value = false
  }
}

function reset() {
  phase.value = 'idle'
  threadId.value = ''
  stateSnapshot.value = null
  classification.value = null
  finalState.value = null
  finalStatus.value = ''
  activeNode.value = ''
  error.value = ''
  editedResponse.value = ''
  emailId.value = 'email-' + Date.now()
}
</script>

<style scoped>
.pg-root { height: 100%; display: flex; flex-direction: column; background: #0f1419; color: #e2e8f0; font-family: 'SF Mono', Menlo, 'PingFang SC', monospace; font-size: 13px; }
.pg-header { flex-shrink: 0; display: flex; align-items: center; justify-content: space-between; padding: 10px 16px; border-bottom: 1px solid #1e293b; background: #111827; }
.pg-header-left { display: flex; align-items: center; gap: 10px; }
.pg-badge { background: #6366f1; color: #fff; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px; }
.pg-title { font-weight: 700; color: #f8fafc; }
.pg-sub { color: #64748b; font-size: 12px; }
.pg-url { font-size: 11px; color: #475569; }
.pg-body { flex: 1; display: flex; overflow: hidden; min-height: 0; }
.pg-config { width: 300px; flex-shrink: 0; overflow-y: auto; border-right: 1px solid #1e293b; padding: 12px; background: #0c1017; }
.pg-section { margin-bottom: 18px; }
.pg-section-title { font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; color: #64748b; margin: 0 0 8px; }
.pg-pipeline { display: flex; flex-direction: column; gap: 4px; }
.pg-pipe-node { display: flex; align-items: center; gap: 8px; opacity: 0.35; font-size: 11px; }
.pg-pipe-node.done { opacity: 0.65; }
.pg-pipe-node.active { opacity: 1; }
.pg-pipe-node.active .pg-pipe-dot { background: #6366f1; color: #fff; }
.pg-pipe-dot { width: 22px; height: 18px; border-radius: 4px; background: #1e293b; color: #64748b; display: flex; align-items: center; justify-content: center; font-size: 9px; font-weight: 700; }
.pg-label { display: block; font-size: 11px; color: #64748b; margin: 6px 0 4px; }
.pg-input, .pg-textarea { width: 100%; box-sizing: border-box; background: #1e293b; border: 1px solid #334155; border-radius: 6px; color: #e2e8f0; padding: 8px; font-size: 12px; font-family: inherit; }
.pg-textarea { resize: vertical; }
.pg-btn { display: block; width: 100%; margin-top: 8px; padding: 8px; border-radius: 6px; border: none; font-size: 12px; font-weight: 600; cursor: pointer; font-family: inherit; }
.pg-btn.primary { background: #6366f1; color: #fff; }
.pg-btn.primary:disabled { opacity: 0.4; cursor: not-allowed; }
.pg-btn.secondary { background: #1e3a5f; color: #93c5fd; }
.pg-btn.secondary:disabled { opacity: 0.4; }
.pg-btn.ghost { background: transparent; color: #64748b; border: 1px solid #334155; }
.pg-btn.sm { width: auto; padding: 4px 8px; margin: 0; font-size: 10px; }
.pg-error { color: #f87171; font-size: 11px; margin-top: 8px; }
.pg-main { flex: 1; overflow-y: auto; padding: 16px; min-width: 0; }
.pg-empty { height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; color: #64748b; padding: 24px; }
.pg-empty-title { font-size: 16px; color: #94a3b8; margin: 0 0 8px; }
.pg-empty-desc { font-size: 12px; line-height: 1.7; max-width: 400px; }
.pg-empty-desc code { background: #1e293b; padding: 2px 6px; border-radius: 4px; color: #a5b4fc; }
.pg-content { display: flex; flex-direction: column; gap: 12px; }
.pg-card { background: #1e293b; border-radius: 8px; padding: 14px; border-left: 3px solid #334155; }
.pg-card.highlight { border-left-color: #6366f1; }
.pg-card.success { border-left-color: #34d399; }
.pg-card h4 { margin: 0 0 8px; font-size: 11px; color: #64748b; text-transform: uppercase; }
.pg-card pre { margin: 0; white-space: pre-wrap; font-size: 12px; line-height: 1.6; color: #cbd5e1; }
.pg-log { width: 280px; flex-shrink: 0; display: flex; flex-direction: column; border-left: 1px solid #1e293b; background: #0c1017; }
.pg-log-header { display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; border-bottom: 1px solid #1e293b; font-size: 11px; color: #64748b; }
.pg-log-list { flex: 1; overflow-y: auto; padding: 8px; }
.pg-log-item { margin-bottom: 8px; padding: 8px; background: #111827; border-radius: 6px; border-left: 2px solid #6366f1; }
.pg-log-ts { font-size: 10px; color: #475569; }
.pg-log-type { font-size: 10px; color: #94a3b8; display: block; margin: 2px 0 4px; }
.pg-log-json { margin: 0; font-size: 10px; color: #64748b; white-space: pre-wrap; word-break: break-all; max-height: 100px; overflow: auto; }
.pg-log-empty { font-size: 11px; color: #475569; text-align: center; padding: 20px; }
</style>
