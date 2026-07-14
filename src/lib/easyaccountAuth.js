const TOKEN_KEY = 'easyaccount_agent_token'
const USER_KEY = 'easyaccount_agent_user'

export function getStoredToken() {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function getStoredUser() {
  try {
    const raw = localStorage.getItem(USER_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function persistSession({ token, user }) {
  if (token) localStorage.setItem(TOKEN_KEY, token)
  if (user) localStorage.setItem(USER_KEY, JSON.stringify(user))
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
}

/** Derive HTTP origin from WS URL, e.g. ws://host:8088 → http://host:8088 */
export function httpBaseFromWs(wsUrl) {
  const raw = (wsUrl || '').trim().replace(/\/$/, '')
  if (!raw) return 'http://127.0.0.1:8088'
  if (raw.startsWith('wss://')) return 'https://' + raw.slice(6)
  if (raw.startsWith('ws://')) return 'http://' + raw.slice(5)
  if (raw.startsWith('https://') || raw.startsWith('http://')) return raw
  return raw
}

export function resolveHttpBase({ httpUrl, wsUrl }) {
  const explicit = (httpUrl || '').trim().replace(/\/$/, '')
  if (explicit) return explicit
  return httpBaseFromWs(wsUrl)
}

async function parseJsonSafe(res) {
  try {
    return await res.json()
  } catch {
    return null
  }
}

export async function login({ httpBase, name, password }) {
  const res = await fetch(`${httpBase}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, password })
  })
  const data = await parseJsonSafe(res)
  if (!res.ok) {
    const err = new Error(data?.message || '登录失败')
    err.status = res.status
    throw err
  }
  return data
}

export async function fetchMe({ httpBase, token }) {
  const res = await fetch(`${httpBase}/api/auth/me`, {
    headers: { Authorization: `Bearer ${token}` }
  })
  const data = await parseJsonSafe(res)
  if (!res.ok) {
    const err = new Error(data?.message || '未登录或会话已失效')
    err.status = res.status
    throw err
  }
  return data
}

export async function logout({ httpBase, token }) {
  if (!token) return
  try {
    await fetch(`${httpBase}/api/auth/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` }
    })
  } catch {
    // ignore network errors on logout
  }
}

export function buildChatWsUrl(wsUrl, token) {
  const base = (wsUrl || 'ws://127.0.0.1:8088').trim().replace(/\/$/, '')
  return `${base}/ws?token=${encodeURIComponent(token)}`
}
