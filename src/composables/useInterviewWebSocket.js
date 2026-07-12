import { ref, computed, watch, nextTick, onBeforeUnmount } from 'vue'

const STEP_DEFS = ['JD 解析', '简历匹配', '出题规划', '模拟问答', '薄弱巩固', '评估报告']

const STAGE_LABELS = {
  jd_analysis: 'jd_analysis',
  jd_analysis_done: 'jd_analysis ✓',
  resume_match: 'resume_match',
  resume_match_done: 'resume_match ✓',
  question_plan: 'question_plan',
  rag_retrieval: 'rag_retrieval',
  rag_retrieval_done: 'rag_retrieval ✓',
  question_plan_done: 'question_plan ✓',
  interview: 'interview',
  interview_done: 'interview ✓',
  terminated: 'terminated',
  review_weak: 'weak_review',
  review_weak_done: 'weak_review ✓',
  evaluation: 'evaluation',
  evaluation_done: 'evaluation ✓'
}

const FRIENDLY_STAGE = {
  jd_analysis: '正在分析职位描述…',
  jd_analysis_done: 'JD 解析完成',
  resume_match: '正在比对简历与岗位要求…',
  resume_match_done: '简历匹配完成',
  question_plan: '正在规划面试题目…',
  rag_retrieval: '正在检索题库…',
  rag_retrieval_done: '题库检索完成',
  question_plan_done: '出题规划完成',
  interview: '模拟面试开始',
  interview_done: '模拟面试结束',
  terminated: '面试已终止',
  review_weak: '正在整理薄弱项…',
  review_weak_done: '薄弱项巩固完成',
  evaluation: '正在生成评估报告…',
  evaluation_done: '评估报告生成完成'
}

function stepIndexForStage(stageKey) {
  const groups = {
    jd_analysis: 0, jd_analysis_done: 0,
    resume_match: 1, resume_match_done: 1,
    question_plan: 2, rag_retrieval: 2, rag_retrieval_done: 2, question_plan_done: 2,
    interview: 3, interview_done: 3, terminated: 3,
    review_weak: 4, review_weak_done: 4,
    evaluation: 5, evaluation_done: 5
  }
  return groups[stageKey] !== undefined ? groups[stageKey] : -1
}

function cleanMd(t) {
  return t.replace(/\*\*/g, '').replace(/`/g, '').trim()
}

function parseMarkdown(md) {
  if (!md) return []
  const lines = md.split('\n')
  const blocks = []
  let para = []
  const flushPara = () => {
    if (para.length) {
      blocks.push({ type: 'p', text: para.join(' ').trim() })
      para = []
    }
  }
  for (const raw of lines) {
    const line = raw.trim()
    if (line === '') { flushPara(); continue }
    if (/^---+$/.test(line) || /^\*\*\*+$/.test(line)) { flushPara(); blocks.push({ type: 'hr' }); continue }
    if (line.indexOf('### ') === 0) { flushPara(); blocks.push({ type: 'h3', text: cleanMd(line.slice(4)) }); continue }
    if (line.indexOf('## ') === 0) { flushPara(); blocks.push({ type: 'h2', text: cleanMd(line.slice(3)) }); continue }
    if (line.indexOf('# ') === 0) { flushPara(); blocks.push({ type: 'h1', text: cleanMd(line.slice(2)) }); continue }
    if (/^[-*]\s+/.test(line)) { flushPara(); blocks.push({ type: 'li', text: cleanMd(line.replace(/^[-*]\s+/, '')) }); continue }
    if (/^\d+\.\s+/.test(line)) { flushPara(); blocks.push({ type: 'li', text: cleanMd(line.replace(/^\d+\.\s+/, '')) }); continue }
    para.push(line)
  }
  flushPara()
  return blocks
}

export function httpBaseFromWsUrl(wsUrl) {
  return (wsUrl || '').trim().replace(/\/$/, '').replace(/^ws(s?):/, 'http$1:')
}

export function useInterviewWebSocket(defaultWsUrl, options = {}) {
  const { systemConnectText = '已连接，正在提交 resume + JD…', onRawMessage } = options

  const stage = ref('setup')
  const jd = ref('')
  const resume = ref('')
  const userId = ref('lab-' + Math.random().toString(36).slice(2, 8))
  const wsUrl = ref(defaultWsUrl || 'ws://localhost:8085')
  const connectError = ref('')
  const messages = ref([])
  const eventLog = ref([])
  const currentStepIndex = ref(-1)
  const waitingForAnswer = ref(false)
  const answerText = ref('')
  const reportMd = ref('')
  const connected = ref(false)

  let ws = null

  const canStart = computed(() => !!(jd.value.trim() && resume.value.trim()))
  const canSend = computed(() => waitingForAnswer.value && !!answerText.value.trim())

  const stepperItems = computed(() => STEP_DEFS.map((label, i) => ({
    label,
    done: i < currentStepIndex.value,
    active: i === currentStepIndex.value
  })))

  const reportBlocks = computed(() => parseMarkdown(reportMd.value))

  function pushMessage(m) {
    messages.value.push({ id: messages.value.length, ...m })
  }

  function pushEvent(direction, payload) {
    const entry = {
      id: eventLog.value.length,
      ts: new Date().toLocaleTimeString('zh-CN', { hour12: false }),
      direction,
      type: payload?.type || (typeof payload === 'string' ? 'text' : 'unknown'),
      payload
    }
    eventLog.value.push(entry)
    if (onRawMessage) onRawMessage(entry)
  }

  function buildWsUrl() {
    const base = wsUrl.value.trim().replace(/\/$/, '')
    return base + '/ws?userId=' + encodeURIComponent(userId.value || 'lab-guest')
  }

  function connectAndStart() {
    stage.value = 'connecting'
    connectError.value = ''
    connected.value = false
    let socket
    try {
      socket = new WebSocket(buildWsUrl())
    } catch {
      stage.value = 'setup'
      connectError.value = '无法创建 WebSocket 连接'
      return
    }
    ws = socket
    pushEvent('sys', { type: 'connect', url: buildWsUrl() })
    socket.onopen = () => { connected.value = true }
    socket.onmessage = (ev) => {
      let msg
      try { msg = JSON.parse(ev.data) } catch { return }
      pushEvent('in', msg)
      handleServerMessage(msg)
    }
    socket.onerror = () => {
      connectError.value = '连接失败，请确认 Playground 后端正在运行'
      pushEvent('sys', { type: 'error', message: 'WebSocket error' })
    }
    socket.onclose = () => {
      connected.value = false
      pushEvent('sys', { type: 'close' })
      if (stage.value === 'connecting') {
        stage.value = 'setup'
        connectError.value = '连接已断开'
      }
    }
  }

  function handleServerMessage(msg) {
    if (msg.type === 'connected') {
      pushMessage({ kind: 'system', text: systemConnectText })
      const outbound = { type: 'start_interview', jd: jd.value, resume: resume.value }
      ws.send(JSON.stringify(outbound))
      pushEvent('out', outbound)
      stage.value = 'live'
    } else if (msg.type === 'stage_change') {
      currentStepIndex.value = Math.max(currentStepIndex.value, stepIndexForStage(msg.stage))
      const label = STAGE_LABELS[msg.stage] || msg.stage
      pushMessage({
        kind: 'system',
        text: msg.message || FRIENDLY_STAGE[msg.stage] || msg.stage,
        stageKey: msg.stage,
        nodeLabel: label
      })
    } else if (msg.type === 'question') {
      pushMessage({ kind: 'question', num: msg.question_num, text: msg.content })
      waitingForAnswer.value = true
    } else if (msg.type === 'score') {
      pushMessage({
        kind: 'score',
        score: msg.score,
        feedback: msg.feedback,
        hit: msg.key_points_hit || [],
        missed: msg.key_points_missed || []
      })
    } else if (msg.type === 'report') {
      reportMd.value = msg.content
      stage.value = 'report'
    } else if (msg.type === 'error') {
      pushMessage({ kind: 'error', text: msg.message })
    } else if (msg.type === 'interview_complete') {
      if (stage.value !== 'report') stage.value = 'ended'
    }
  }

  function onStart() {
    if (!canStart.value) return
    connectAndStart()
  }

  function sendAnswer() {
    const text = answerText.value.trim()
    if (!text || !waitingForAnswer.value) return
    const outbound = { type: 'answer', content: text }
    ws.send(JSON.stringify(outbound))
    pushEvent('out', outbound)
    pushMessage({ kind: 'answer', text })
    answerText.value = ''
    waitingForAnswer.value = false
  }

  function quitInterview() {
    if (ws) {
      const outbound = { type: 'quit_interview' }
      ws.send(JSON.stringify(outbound))
      pushEvent('out', outbound)
    }
    pushMessage({ kind: 'system', text: '已发送 quit_interview' })
  }

  function restart() {
    if (ws) { try { ws.close() } catch { /* ignore */ } ws = null }
    stage.value = 'setup'
    messages.value = []
    eventLog.value = []
    reportMd.value = ''
    connectError.value = ''
    waitingForAnswer.value = false
    answerText.value = ''
    currentStepIndex.value = -1
    connected.value = false
  }

  onBeforeUnmount(() => {
    if (ws) { try { ws.close() } catch { /* ignore */ } }
  })

  return {
    stage,
    jd,
    resume,
    userId,
    wsUrl,
    connectError,
    messages,
    eventLog,
    currentStepIndex,
    waitingForAnswer,
    answerText,
    reportMd,
    connected,
    canStart,
    canSend,
    stepperItems,
    reportBlocks,
    stepDefs: STEP_DEFS,
    buildWsUrl,
    onStart,
    sendAnswer,
    quitInterview,
    restart,
    pushEvent,
    httpBase: computed(() => httpBaseFromWsUrl(wsUrl.value))
  }
}
