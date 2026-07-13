<template>
  <div class="ea-root">
    <header class="ea-header">
      <div class="ea-header-inner">
        <span class="ea-dot"></span>
        <div class="ea-header-text">
          <div class="ea-title">{{ title }}</div>
          <div v-if="stage === 'live'" class="ea-sub">{{ connected ? '已连接 · 随时记账' : '连接中…' }}</div>
        </div>
      </div>
      <button v-if="stage === 'live'" class="ea-text-btn" type="button" @click="restart">结束</button>
    </header>

    <!-- Setup -->
    <div v-if="stage === 'setup'" class="ea-setup">
      <div class="ea-hero">
        <div class="ea-icon">¥</div>
        <h1>智能记账</h1>
        <p>查余额、记流水、看报表，用对话完成。</p>
      </div>
      <div class="ea-card">
        <button class="ea-primary-btn" type="button" @click="onStart">开始记账对话</button>
        <button class="ea-link-btn" type="button" @click="showAdvanced = !showAdvanced">
          {{ showAdvanced ? '收起设置' : '连接设置' }}
        </button>
        <div v-if="showAdvanced" class="ea-advanced">
          <label>用户 ID</label>
          <input v-model="userId" />
          <label>WebSocket</label>
          <input v-model="wsUrl" />
        </div>
        <div v-if="connectError" class="ea-error">{{ connectError }}</div>
      </div>
    </div>

    <!-- Connecting -->
    <div v-else-if="stage === 'connecting'" class="ea-center">
      <div class="ea-spinner"></div>
      <span>正在连接记账助手…</span>
    </div>

    <!-- Live chat -->
    <div v-else class="ea-live">
      <div ref="transcriptRef" class="ea-transcript">
        <div class="ea-messages">
          <template v-for="m in messages" :key="m.id">
            <div v-if="m.kind === 'system'" class="ea-bubble ea-system">{{ m.text }}</div>
            <div v-else-if="m.kind === 'assistant'" class="ea-bubble ea-assistant">
              <div class="ea-role">记账助手</div>
              <div class="ea-content">{{ m.text }}<span v-if="m.streaming" class="ea-cursor">▍</span></div>
            </div>
            <div v-else-if="m.kind === 'user'" class="ea-bubble ea-user">{{ m.text }}</div>
            <div v-else-if="m.kind === 'error'" class="ea-bubble ea-error">{{ m.text }}</div>
          </template>
        </div>
      </div>

      <div class="ea-composer">
        <textarea
          v-model="inputText"
          rows="1"
          :placeholder="waitingReply ? '助手正在回复…' : '说点什么，例如：查一下账户余额'"
          :disabled="waitingReply"
          @keydown.enter.exact.prevent="sendChat"
        ></textarea>
        <button type="button" class="ea-send" :disabled="!canSend" @click="sendChat">发送</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onBeforeUnmount } from 'vue'

const props = defineProps({
  title: { type: String, default: '记账助手' },
  defaultWsUrl: { type: String, default: '' }
})

const stage = ref('setup')
const userId = ref('mobile-' + Math.random().toString(36).slice(2, 8))
const wsUrl = ref(props.defaultWsUrl || import.meta.env.VITE_EASYACCOUNT_WS_URL || 'ws://localhost:8088')
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
  const base = (wsUrl.value || 'ws://localhost:8088').trim().replace(/\/$/, '')
  return base + '/ws?userId=' + encodeURIComponent(userId.value || 'mobile-guest')
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
    connectError.value = '无法创建连接，请检查地址'
    return
  }
  ws = socket
  socket.onmessage = (ev) => {
    let msg
    try { msg = JSON.parse(ev.data) } catch (e) { return }
    handleServerMessage(msg)
  }
  socket.onerror = () => {
    connectError.value = '连接失败，请确认 easyaccount-agent 已启动'
  }
  socket.onclose = () => {
    connected.value = false
    if (stage.value === 'connecting') {
      stage.value = 'setup'
      connectError.value = '连接已断开，请检查服务与网络'
    } else if (stage.value === 'live') {
      pushMessage({ kind: 'system', text: '连接已断开' })
    }
  }
}

function handleServerMessage(msg) {
  if (msg.type === 'connected') {
    connected.value = true
    stage.value = 'live'
    pushMessage({ kind: 'system', text: msg.content || '记账助手已连接' })
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
      updateMessage(streamingMsgId, {
        text: msg.content || messages.value.find(m => m.id === streamingMsgId)?.text || '',
        streaming: false
      })
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

<style scoped>
.ea-root {
  height: 100%;
  width: 100%;
  display: flex;
  flex-direction: column;
  background: #f2f2f7;
  color: #1c1c1e;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'PingFang SC', sans-serif;
  overflow: hidden;
}

.ea-header {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: max(10px, env(safe-area-inset-top)) 16px 10px;
  background: rgba(242, 242, 247, 0.92);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid rgba(60, 60, 67, 0.12);
}

.ea-header-inner { display: flex; align-items: center; gap: 10px; min-width: 0; }
.ea-dot { width: 8px; height: 8px; border-radius: 50%; background: #34c759; flex-shrink: 0; }
.ea-title { font-size: 17px; font-weight: 600; line-height: 1.2; }
.ea-sub { font-size: 12px; color: #8e8e93; margin-top: 2px; }
.ea-text-btn {
  border: none; background: transparent; color: #007aff; font-size: 15px; font-weight: 500; padding: 8px;
}

.ea-setup {
  flex: 1;
  overflow-y: auto;
  padding: 24px 16px calc(24px + env(safe-area-inset-bottom));
}

.ea-hero { text-align: center; padding: 28px 8px 20px; }
.ea-icon {
  width: 64px; height: 64px; margin: 0 auto 16px; border-radius: 18px;
  background: linear-gradient(145deg, #34c759, #30b0c7);
  color: #fff; font-size: 28px; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 12px 28px rgba(52, 199, 89, 0.25);
}
.ea-hero h1 { margin: 0; font-size: 28px; font-weight: 700; letter-spacing: -0.02em; }
.ea-hero p { margin: 10px 0 0; color: #8e8e93; font-size: 15px; line-height: 1.5; }

.ea-card {
  background: #fff; border-radius: 18px; padding: 18px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
}

.ea-primary-btn {
  width: 100%; border: none; border-radius: 14px; padding: 15px;
  background: #007aff; color: #fff; font-size: 17px; font-weight: 600;
}

.ea-link-btn {
  width: 100%; margin-top: 10px; border: none; background: transparent;
  color: #8e8e93; font-size: 14px; padding: 8px;
}

.ea-advanced { margin-top: 14px; display: flex; flex-direction: column; gap: 8px; }
.ea-advanced label { font-size: 12px; color: #8e8e93; }
.ea-advanced input {
  width: 100%; box-sizing: border-box; border: 1px solid rgba(60,60,67,0.18);
  border-radius: 10px; padding: 10px 12px; font-size: 14px; background: #f9f9fb;
}

.ea-error {
  margin-top: 12px; padding: 10px 12px; border-radius: 12px;
  background: rgba(255, 59, 48, 0.1); color: #d70015; font-size: 14px;
}

.ea-center {
  flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 14px; color: #8e8e93; font-size: 15px;
}

.ea-spinner {
  width: 12px; height: 12px; border-radius: 50%; background: #007aff;
  animation: eaPulse 1.2s ease-in-out infinite;
}

.ea-live { flex: 1; display: flex; flex-direction: column; min-height: 0; }

.ea-transcript {
  flex: 1; overflow-y: auto; -webkit-overflow-scrolling: touch;
  padding: 12px 12px 8px;
}

.ea-messages { max-width: 720px; margin: 0 auto; display: flex; flex-direction: column; gap: 10px; }

.ea-bubble { max-width: 88%; word-break: break-word; }
.ea-system {
  align-self: center; font-size: 12px; color: #8e8e93;
  background: rgba(120, 120, 128, 0.12); padding: 5px 12px; border-radius: 999px;
}
.ea-assistant {
  align-self: flex-start; background: #fff; border-radius: 18px 18px 18px 6px;
  padding: 12px 14px; box-shadow: 0 2px 8px rgba(0,0,0,0.05);
}
.ea-role { font-size: 11px; font-weight: 700; color: #34c759; margin-bottom: 4px; letter-spacing: 0.04em; }
.ea-content { font-size: 16px; line-height: 1.55; white-space: pre-wrap; }
.ea-cursor { opacity: 0.35; }
.ea-user {
  align-self: flex-end; background: #007aff; color: #fff;
  border-radius: 18px 18px 6px 18px; padding: 10px 14px; font-size: 16px; line-height: 1.5;
}

.ea-composer {
  flex-shrink: 0;
  display: flex; align-items: flex-end; gap: 8px;
  padding: 8px 12px calc(8px + env(safe-area-inset-bottom));
  background: rgba(242, 242, 247, 0.96);
  border-top: 1px solid rgba(60, 60, 67, 0.12);
}

.ea-composer textarea {
  flex: 1; min-height: 40px; max-height: 120px; resize: none;
  border: 1px solid rgba(60,60,67,0.16); border-radius: 20px;
  padding: 10px 14px; font-size: 16px; line-height: 1.4; background: #fff; outline: none;
}

.ea-send {
  flex-shrink: 0; border: none; border-radius: 20px; padding: 10px 16px;
  background: #007aff; color: #fff; font-size: 15px; font-weight: 600;
}
.ea-send:disabled { opacity: 0.4; }

@keyframes eaPulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.35; transform: scale(0.92); }
}

@media (min-width: 769px) {
  .ea-setup { max-width: 480px; margin: 0 auto; width: 100%; }
}
</style>
