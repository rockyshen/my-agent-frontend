<template>
  <div class="ea-root">
    <header class="ea-header">
      <div class="ea-header-inner">
        <span class="ea-dot" :class="{ offline: stage === 'live' && !connected }"></span>
        <div class="ea-header-text">
          <div class="ea-title">{{ title }}</div>
          <div v-if="stage === 'live'" class="ea-sub">
            <template v-if="connected">已连接{{ currentUser?.name ? ` · ${currentUser.name}` : '' }}</template>
            <template v-else>连接中…</template>
          </div>
          <div v-else-if="stage === 'bootstrapping'" class="ea-sub">校验登录中…</div>
        </div>
      </div>
      <button
        v-if="stage === 'live' || stage === 'connecting'"
        class="ea-text-btn"
        type="button"
        @click="onLogout"
      >退出</button>
    </header>

    <!-- Bootstrapping session -->
    <div v-if="stage === 'bootstrapping'" class="ea-center">
      <div class="ea-spinner"></div>
      <span>正在恢复登录状态…</span>
    </div>

    <!-- Login -->
    <div v-else-if="stage === 'login'" class="ea-setup">
      <div class="ea-hero">
        <div class="ea-icon">¥</div>
        <h1>智能记账</h1>
        <p>登录后查余额、记流水；账本按账号隔离。</p>
      </div>
      <div class="ea-card">
        <form class="ea-form" @submit.prevent="onLogin">
          <label for="ea-name">用户名</label>
          <input
            id="ea-name"
            v-model="loginName"
            type="text"
            autocomplete="username"
            placeholder="例如 rocky"
            :disabled="loginBusy"
          />
          <label for="ea-password">密码</label>
          <input
            id="ea-password"
            v-model="loginPassword"
            type="password"
            inputmode="numeric"
            autocomplete="current-password"
            placeholder="数字密码"
            :disabled="loginBusy"
          />
          <button class="ea-primary-btn" type="submit" :disabled="!canLogin">
            {{ loginBusy ? '登录中…' : '登录' }}
          </button>
        </form>
        <button class="ea-link-btn" type="button" @click="showAdvanced = !showAdvanced">
          {{ showAdvanced ? '收起设置' : '连接设置' }}
        </button>
        <div v-if="showAdvanced" class="ea-advanced">
          <label>HTTP Base</label>
          <input v-model="httpBase" />
          <label>WebSocket</label>
          <input v-model="wsUrl" />
        </div>
        <div v-if="authError" class="ea-error">{{ authError }}</div>
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
          :placeholder="waitingReply ? '助手正在回复…' : '说点什么，例如：列出我的账户'"
          :disabled="waitingReply || !connected"
          @keydown.enter.exact.prevent="sendChat"
        ></textarea>
        <button type="button" class="ea-send" :disabled="!canSend" @click="sendChat">发送</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import {
  getStoredToken,
  getStoredUser,
  persistSession,
  clearSession,
  resolveHttpBase,
  login,
  fetchMe,
  logout,
  buildChatWsUrl
} from '../lib/easyaccountAuth.js'

const props = defineProps({
  title: { type: String, default: '记账助手' },
  defaultWsUrl: { type: String, default: '' },
  defaultHttpUrl: { type: String, default: '' }
})

/** @type {import('vue').Ref<'bootstrapping'|'login'|'connecting'|'live'>} */
const stage = ref('bootstrapping')
const wsUrl = ref(props.defaultWsUrl || import.meta.env.VITE_EASYACCOUNT_WS_URL || 'ws://127.0.0.1:8088')
const httpBase = ref(
  resolveHttpBase({
    httpUrl: props.defaultHttpUrl || import.meta.env.VITE_EASYACCOUNT_HTTP_URL,
    wsUrl: wsUrl.value
  })
)
const showAdvanced = ref(false)
const authError = ref('')
const loginName = ref('')
const loginPassword = ref('')
const loginBusy = ref(false)
const currentUser = ref(null)
const token = ref('')
const connected = ref(false)
const messages = ref([])
const inputText = ref('')
const waitingReply = ref(false)
const transcriptRef = ref(null)

let ws = null
let streamingMsgId = null
let reconnectTimer = null
let reconnectAttempts = 0
let intentionalClose = false
let sessionInvalidHandled = false

const canLogin = computed(() => {
  const name = loginName.value.trim()
  const pwd = loginPassword.value.trim()
  return !loginBusy.value && !!name && pwd !== '' && Number.isInteger(Number(pwd))
})

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

function clearReconnect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer)
    reconnectTimer = null
  }
}

function resetChatState() {
  messages.value = []
  authError.value = ''
  connected.value = false
  waitingReply.value = false
  inputText.value = ''
  streamingMsgId = null
}

function closeWs() {
  intentionalClose = true
  clearReconnect()
  if (ws) {
    try { ws.close() } catch { /* ignore */ }
    ws = null
  }
}

async function forceToLogin(message) {
  if (sessionInvalidHandled) return
  sessionInvalidHandled = true
  clearReconnect()
  closeWs()
  clearSession()
  token.value = ''
  currentUser.value = null
  resetChatState()
  stage.value = 'login'
  authError.value = message || '登录已失效，请重新登录'
  sessionInvalidHandled = false
}

async function bootstrap() {
  stage.value = 'bootstrapping'
  authError.value = ''
  const stored = getStoredToken()
  if (!stored) {
    stage.value = 'login'
    currentUser.value = null
    return
  }
  token.value = stored
  currentUser.value = getStoredUser()
  try {
    const me = await fetchMe({ httpBase: httpBase.value, token: stored })
    currentUser.value = me
    persistSession({ token: stored, user: me })
    connectWs()
  } catch (e) {
    if (e.status === 401) {
      clearSession()
      token.value = ''
      currentUser.value = null
      stage.value = 'login'
      authError.value = e.message || '未登录或会话已失效'
      return
    }
    // network error: still allow login page; keep token so retry possible
    stage.value = 'login'
    authError.value = e.message || '无法校验登录，请检查服务地址'
  }
}

async function onLogin() {
  const name = loginName.value.trim()
  const pwdRaw = loginPassword.value.trim()
  const password = Number(pwdRaw)
  if (!name || !Number.isInteger(password)) {
    authError.value = '请输入用户名，密码须为整数'
    return
  }
  loginBusy.value = true
  authError.value = ''
  try {
    const data = await login({ httpBase: httpBase.value, name, password })
    persistSession({ token: data.token, user: data.user })
    token.value = data.token
    currentUser.value = data.user || { name }
    loginPassword.value = ''
    resetChatState()
    connectWs()
  } catch (e) {
    authError.value = e.message || '登录失败'
  } finally {
    loginBusy.value = false
  }
}

function connectWs() {
  if (!token.value) {
    forceToLogin('请先登录')
    return
  }
  clearReconnect()
  intentionalClose = false
  if (stage.value !== 'live') stage.value = 'connecting'
  connected.value = false

  let socket
  try {
    socket = new WebSocket(buildChatWsUrl(wsUrl.value, token.value))
  } catch {
    stage.value = 'login'
    authError.value = '无法创建连接，请检查地址'
    return
  }
  ws = socket

  socket.onmessage = (ev) => {
    let msg
    try { msg = JSON.parse(ev.data) } catch { return }
    handleServerMessage(msg)
  }

  socket.onerror = () => {
    // browsers hide handshake status; onclose + /me will classify auth vs network
  }

  socket.onclose = async () => {
    connected.value = false
    ws = null
    if (intentionalClose) {
      intentionalClose = false
      return
    }

    if (stage.value === 'connecting') {
      const stillValid = await checkSessionStillValid()
      if (!stillValid) {
        await forceToLogin('未登录或会话已失效')
        return
      }
      reconnectAttempts += 1
      if (reconnectAttempts >= 3) {
        stage.value = 'login'
        authError.value = '连接失败，请确认 easyaccount-agent 已启动'
        reconnectAttempts = 0
        return
      }
      reconnectTimer = setTimeout(() => connectWs(), 800 * reconnectAttempts)
      return
    }

    if (stage.value === 'live') {
      pushMessage({ kind: 'system', text: '连接已断开，正在重连…' })
      const stillValid = await checkSessionStillValid()
      if (!stillValid) {
        await forceToLogin('会话已失效（可能被其他设备登录踢下线）')
        return
      }
      reconnectAttempts += 1
      const delay = Math.min(8000, 600 * reconnectAttempts)
      reconnectTimer = setTimeout(() => connectWs(), delay)
    }
  }
}

async function checkSessionStillValid() {
  if (!token.value) return false
  try {
    const me = await fetchMe({ httpBase: httpBase.value, token: token.value })
    currentUser.value = me
    persistSession({ token: token.value, user: me })
    return true
  } catch (e) {
    if (e.status === 401) return false
    // network blip: treat as still valid so WS can retry
    return true
  }
}

function handleServerMessage(msg) {
  if (msg.type === 'connected') {
    connected.value = true
    stage.value = 'live'
    reconnectAttempts = 0
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
  if (!text || !connected.value || waitingReply.value || !ws) return
  ws.send(JSON.stringify({ type: 'chat', content: text }))
  pushMessage({ kind: 'user', text })
  inputText.value = ''
  waitingReply.value = true
  streamingMsgId = null
}

async function onLogout() {
  const t = token.value
  closeWs()
  await logout({ httpBase: httpBase.value, token: t })
  clearSession()
  token.value = ''
  currentUser.value = null
  resetChatState()
  stage.value = 'login'
  authError.value = ''
}

onMounted(() => {
  bootstrap()
})

onBeforeUnmount(() => {
  intentionalClose = true
  clearReconnect()
  if (ws) { try { ws.close() } catch { /* ignore */ } }
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
.ea-dot.offline { background: #ff9f0a; }
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

.ea-form { display: flex; flex-direction: column; gap: 8px; }
.ea-form label { font-size: 12px; color: #8e8e93; }
.ea-form input {
  width: 100%; box-sizing: border-box; border: 1px solid rgba(60,60,67,0.18);
  border-radius: 10px; padding: 12px 14px; font-size: 16px; background: #f9f9fb; margin-bottom: 6px;
}

.ea-primary-btn {
  width: 100%; border: none; border-radius: 14px; padding: 15px; margin-top: 8px;
  background: #007aff; color: #fff; font-size: 17px; font-weight: 600;
}
.ea-primary-btn:disabled { opacity: 0.45; }

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
