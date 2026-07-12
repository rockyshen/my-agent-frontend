<template>
  <div style="height:100%;width:100%;background:#faf8f4;color:#1d1d1f;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','PingFang SC','Helvetica Neue',Arial,sans-serif;display:flex;flex-direction:column;overflow:hidden;">

    <div style="flex-shrink:0;display:flex;align-items:center;justify-content:space-between;padding:0 40px;height:64px;border-bottom:1px solid rgba(0,0,0,0.08);background:#faf8f4;">
      <div style="display:flex;align-items:center;gap:10px;">
        <div style="width:8px;height:8px;border-radius:50%;background:#8a6f45;"></div>
        <span style="font-size:15px;font-weight:600;letter-spacing:0.01em;">{{ title }}</span>
      </div>
      <span v-if="stage === 'live'" style="font-size:13px;color:#6e6e73;">{{ connected ? '已连接' : '连接中…' }}</span>
    </div>

    <!-- Setup -->
    <div v-if="stage === 'setup'" style="flex:1;overflow-y:auto;">
      <div style="max-width:640px;margin:0 auto;padding:72px 24px 100px;">
        <h1 style="font-size:52px;line-height:1.08;font-weight:600;letter-spacing:-0.02em;text-align:center;margin:0;">和 MyAgent<br />聊聊天气</h1>
        <p style="font-size:18px;color:#6e6e73;text-align:center;margin:20px auto 0;max-width:460px;line-height:1.6;">基于 Spring AI Alibaba ReactAgent 的智能助手，可查询天气并记住对话上下文。</p>

        <div style="margin-top:52px;background:#ffffff;border:1px solid rgba(0,0,0,0.08);border-radius:20px;padding:40px;box-shadow:0 20px 40px rgba(0,0,0,0.04);">
          <div style="margin-top:12px;">
            <span @click="showAdvanced = !showAdvanced" style="font-size:13px;color:#6e6e73;cursor:pointer;user-select:none;">{{ showAdvanced ? '▾' : '▸' }} 高级设置</span>
          </div>

          <div v-if="showAdvanced" style="margin-top:16px;display:flex;gap:12px;">
            <div style="flex:1;">
              <label style="display:block;font-size:12px;color:#6e6e73;margin-bottom:6px;">用户标识</label>
              <input v-model="userId" style="width:100%;border:1px solid rgba(0,0,0,0.12);border-radius:10px;padding:10px 12px;font-size:14px;font-family:inherit;outline:none;box-sizing:border-box;" />
            </div>
            <div style="flex:1;">
              <label style="display:block;font-size:12px;color:#6e6e73;margin-bottom:6px;">WebSocket 地址</label>
              <input v-model="wsUrl" style="width:100%;border:1px solid rgba(0,0,0,0.12);border-radius:10px;padding:10px 12px;font-size:14px;font-family:inherit;outline:none;box-sizing:border-box;" />
            </div>
          </div>

          <button @click="onStart" :style="startBtnStyle">开始对话</button>

          <div v-if="connectError" style="margin-top:16px;background:rgba(192,82,63,0.08);border:1px solid rgba(192,82,63,0.2);color:#a8442f;border-radius:12px;padding:12px 16px;font-size:14px;">{{ connectError }}</div>
        </div>
      </div>
    </div>

    <!-- Connecting -->
    <div v-if="stage === 'connecting'" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;">
      <div style="width:12px;height:12px;border-radius:50%;background:#8a6f45;animation:pulseDot 1.2s ease-in-out infinite;"></div>
      <span style="font-size:16px;color:#6e6e73;">正在连接 MyAgent…</span>
    </div>

    <!-- Live -->
    <div v-if="stage === 'live'" style="flex:1;display:flex;flex-direction:column;overflow:hidden;position:relative;">
      <div ref="transcriptRef" style="flex:1;overflow-y:auto;padding:32px 40px;">
        <div style="max-width:680px;margin:0 auto;display:flex;flex-direction:column;gap:16px;">
          <template v-for="m in messages" :key="m.id">
            <div v-if="m.kind === 'system'" style="align-self:center;background:rgba(0,0,0,0.04);color:#6e6e73;font-size:13px;padding:6px 14px;border-radius:980px;">{{ m.text }}</div>

            <div v-else-if="m.kind === 'assistant'" style="align-self:flex-start;max-width:600px;background:#ffffff;border:1px solid rgba(0,0,0,0.08);border-radius:16px;padding:20px 24px;box-shadow:0 8px 24px rgba(0,0,0,0.04);">
              <div style="font-size:12px;font-weight:700;letter-spacing:0.04em;color:#8a6f45;text-transform:uppercase;margin-bottom:8px;">MyAgent</div>
              <div style="font-size:16px;line-height:1.7;color:#1d1d1f;white-space:pre-wrap;">{{ m.text }}<span v-if="m.streaming" style="opacity:0.4;">▍</span></div>
            </div>

            <div v-else-if="m.kind === 'user'" style="align-self:flex-end;max-width:560px;background:#f1ece0;border-radius:16px;padding:16px 20px;font-size:15px;line-height:1.6;color:#1d1d1f;white-space:pre-wrap;">{{ m.text }}</div>

            <div v-else-if="m.kind === 'error'" style="align-self:center;background:rgba(192,82,63,0.08);border:1px solid rgba(192,82,63,0.2);color:#a8442f;border-radius:12px;padding:10px 16px;font-size:13px;">{{ m.text }}</div>
          </template>
        </div>
      </div>

      <div style="flex-shrink:0;border-top:1px solid rgba(0,0,0,0.08);background:#ffffff;padding:16px 40px;">
        <div style="max-width:680px;margin:0 auto;display:flex;align-items:flex-end;gap:12px;">
          <textarea
            v-model="inputText"
            @keydown.enter.exact.prevent="sendChat"
            :placeholder="waitingReply ? 'MyAgent 正在回复…' : '输入消息…'"
            :disabled="waitingReply"
            style="flex:1;min-height:48px;max-height:140px;border:1px solid rgba(0,0,0,0.12);border-radius:14px;padding:12px 16px;font-size:15px;line-height:1.5;font-family:inherit;resize:none;outline:none;"
          ></textarea>
          <button @click="sendChat" :style="sendBtnStyle">发送</button>
          <span @click="restart" style="font-size:13px;color:#6e6e73;cursor:pointer;white-space:nowrap;padding-bottom:14px;">结束对话</span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onBeforeUnmount } from 'vue'

const props = defineProps({
  title: { type: String, default: 'MyAgent' },
  defaultWsUrl: { type: String, default: '' }
})

const stage = ref('setup')
const userId = ref('web-' + Math.random().toString(36).slice(2, 8))
const wsUrl = ref(props.defaultWsUrl || import.meta.env.VITE_PLAYGROUND_WS_URL || 'ws://localhost:8087')
const showAdvanced = ref(false)
const connectError = ref('')
const connected = ref(false)
const messages = ref([])
const inputText = ref('')
const waitingReply = ref(false)
const transcriptRef = ref(null)

let ws = null
let streamingMsgId = null

const canSend = computed(() => connected.value && !waitingReply.value && !!inputText.value.trim())

const startBtnStyle = computed(() => ({
  marginTop: '20px', width: '100%', background: '#1d1d1f', color: '#fff', border: 'none',
  borderRadius: '980px', padding: '16px 0', fontSize: '17px', fontWeight: 600,
  cursor: 'pointer', transition: 'opacity .2s'
}))

const sendBtnStyle = computed(() => ({
  background: '#1d1d1f', color: '#fff', border: 'none', borderRadius: '980px',
  padding: '13px 22px', fontSize: '15px', fontWeight: 600,
  cursor: canSend.value ? 'pointer' : 'not-allowed', opacity: canSend.value ? 1 : 0.4
}))

watch(messages, async () => {
  await nextTick()
  if (transcriptRef.value) transcriptRef.value.scrollTop = transcriptRef.value.scrollHeight
}, { deep: true })

function pushMessage(m) {
  messages.value.push({ id: messages.value.length, ...m })
}

function updateMessage(id, patch) {
  const idx = messages.value.findIndex(m => m.id === id)
  if (idx >= 0) messages.value[idx] = { ...messages.value[idx], ...patch }
}

function buildWsUrl() {
  const base = (wsUrl.value || 'ws://localhost:8087').trim().replace(/\/$/, '')
  return base + '/ws?userId=' + encodeURIComponent(userId.value || 'web-guest')
}

function onStart() {
  connect()
}

function connect() {
  stage.value = 'connecting'
  connectError.value = ''
  connected.value = false
  let socket
  try {
    socket = new WebSocket(buildWsUrl())
  } catch (e) {
    stage.value = 'setup'
    connectError.value = '无法创建连接，请检查地址格式'
    return
  }
  ws = socket
  socket.onopen = () => {}
  socket.onmessage = (ev) => {
    let msg
    try { msg = JSON.parse(ev.data) } catch (e) { return }
    handleServerMessage(msg)
  }
  socket.onerror = () => {
    connectError.value = '连接失败，请确认后端服务正在运行'
  }
  socket.onclose = () => {
    connected.value = false
    if (stage.value === 'connecting') {
      stage.value = 'setup'
      connectError.value = '连接已断开，请确认后端服务地址与状态'
    } else if (stage.value === 'live') {
      pushMessage({ kind: 'system', text: '连接已断开' })
    }
  }
}

function handleServerMessage(msg) {
  if (msg.type === 'connected') {
    connected.value = true
    stage.value = 'live'
    pushMessage({ kind: 'system', text: msg.content || '连接成功，可以开始对话' })
  } else if (msg.type === 'message_delta') {
    if (streamingMsgId === null) {
      streamingMsgId = messages.value.length
      pushMessage({ kind: 'assistant', text: msg.content || '', streaming: true })
    } else {
      const cur = messages.value.find(m => m.id === streamingMsgId)
      if (cur) updateMessage(streamingMsgId, { text: (cur.text || '') + (msg.content || '') })
    }
  } else if (msg.type === 'message_end') {
    if (streamingMsgId !== null) {
      updateMessage(streamingMsgId, { text: msg.content || messages.value.find(m => m.id === streamingMsgId)?.text || '', streaming: false })
      streamingMsgId = null
    } else if (msg.content) {
      pushMessage({ kind: 'assistant', text: msg.content })
    }
    waitingReply.value = false
  } else if (msg.type === 'error') {
    pushMessage({ kind: 'error', text: msg.message || '发生错误' })
    if (streamingMsgId !== null) {
      updateMessage(streamingMsgId, { streaming: false })
      streamingMsgId = null
    }
    waitingReply.value = false
  }
}

function sendChat() {
  const text = inputText.value.trim()
  if (!text || !connected.value || waitingReply.value) return
  ws.send(JSON.stringify({ type: 'chat', content: text }))
  pushMessage({ kind: 'user', text })
  inputText.value = ''
  waitingReply.value = true
  streamingMsgId = null
}

function restart() {
  if (ws) { try { ws.close() } catch (e) {} ws = null }
  stage.value = 'setup'
  messages.value = []
  connectError.value = ''
  connected.value = false
  waitingReply.value = false
  inputText.value = ''
  streamingMsgId = null
}

onBeforeUnmount(() => {
  if (ws) { try { ws.close() } catch (e) {} }
})
</script>

<style>
@keyframes pulseDot { 0%, 100% { opacity: 1; } 50% { opacity: 0.25; } }
</style>
