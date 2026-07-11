<template>
  <div style="height:100%;width:100%;background:#faf8f4;color:#1d1d1f;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','PingFang SC','Helvetica Neue',Arial,sans-serif;display:flex;flex-direction:column;overflow:hidden;">

    <div style="flex-shrink:0;display:flex;align-items:center;justify-content:space-between;padding:0 40px;height:64px;border-bottom:1px solid rgba(0,0,0,0.08);background:#faf8f4;">
      <div style="display:flex;align-items:center;gap:10px;">
        <div style="width:8px;height:8px;border-radius:50%;background:#8a6f45;"></div>
        <span style="font-size:15px;font-weight:600;letter-spacing:0.01em;">AI 面试官</span>
      </div>
      <div v-if="stage === 'live'" style="display:flex;align-items:center;gap:2px;">
        <template v-for="(st, i) in stepperItems" :key="i">
          <span v-if="i > 0" style="color:#c7c7cc;font-size:13px;margin:0 6px;">›</span>
          <span :style="st.style">{{ st.label }}</span>
        </template>
      </div>
      <span v-if="stage === 'report'" style="font-size:13px;color:#6e6e73;">评估报告</span>
    </div>

    <!-- Setup -->
    <div v-if="stage === 'setup'" style="flex:1;overflow-y:auto;">
      <div style="max-width:640px;margin:0 auto;padding:72px 24px 100px;">
        <h1 style="font-size:52px;line-height:1.08;font-weight:600;letter-spacing:-0.02em;text-align:center;margin:0;">为下一场面试<br />做好万全准备</h1>
        <p style="font-size:18px;color:#6e6e73;text-align:center;margin:20px auto 0;max-width:460px;line-height:1.6;">粘贴职位描述与你的简历，AI 面试官将为你量身定制一场沉浸式模拟面试。</p>

        <div style="margin-top:52px;background:#ffffff;border:1px solid rgba(0,0,0,0.08);border-radius:20px;padding:40px;box-shadow:0 20px 40px rgba(0,0,0,0.04);">
          <div style="margin-bottom:24px;">
            <label style="display:block;font-size:13px;font-weight:600;color:#6e6e73;letter-spacing:0.02em;margin-bottom:8px;">职位描述 JD</label>
            <textarea v-model="jd" placeholder="粘贴职位要求、技能、岗位职责……" style="width:100%;min-height:104px;border:1px solid rgba(0,0,0,0.12);border-radius:12px;padding:14px 16px;font-size:15px;line-height:1.6;font-family:inherit;color:#1d1d1f;resize:vertical;outline:none;"></textarea>
          </div>
          <div style="margin-bottom:8px;">
            <label style="display:block;font-size:13px;font-weight:600;color:#6e6e73;letter-spacing:0.02em;margin-bottom:8px;">你的简历</label>
            <textarea v-model="resume" placeholder="姓名、经验年限、掌握的技术栈……" style="width:100%;min-height:104px;border:1px solid rgba(0,0,0,0.12);border-radius:12px;padding:14px 16px;font-size:15px;line-height:1.6;font-family:inherit;color:#1d1d1f;resize:vertical;outline:none;"></textarea>
          </div>

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

          <button @click="onStart" :style="startBtnStyle">开始模拟面试</button>

          <div v-if="connectError" style="margin-top:16px;background:rgba(192,82,63,0.08);border:1px solid rgba(192,82,63,0.2);color:#a8442f;border-radius:12px;padding:12px 16px;font-size:14px;">{{ connectError }}</div>
        </div>
      </div>
    </div>

    <!-- Connecting -->
    <div v-if="stage === 'connecting'" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;">
      <div style="width:12px;height:12px;border-radius:50%;background:#8a6f45;animation:pulseDot 1.2s ease-in-out infinite;"></div>
      <span style="font-size:16px;color:#6e6e73;">正在连接面试官…</span>
    </div>

    <!-- Live -->
    <div v-if="stage === 'live'" style="flex:1;display:flex;flex-direction:column;overflow:hidden;position:relative;">
      <div ref="transcriptRef" style="flex:1;overflow-y:auto;padding:32px 40px;">
        <div style="max-width:680px;margin:0 auto;display:flex;flex-direction:column;gap:16px;">
          <template v-for="m in messages" :key="m.id">
            <div v-if="m.kind === 'system'" style="align-self:center;background:rgba(0,0,0,0.04);color:#6e6e73;font-size:13px;padding:6px 14px;border-radius:980px;">{{ m.text }}</div>

            <div v-else-if="m.kind === 'question'" style="align-self:flex-start;max-width:600px;background:#ffffff;border:1px solid rgba(0,0,0,0.08);border-radius:16px;padding:20px 24px;box-shadow:0 8px 24px rgba(0,0,0,0.04);">
              <div style="font-size:12px;font-weight:700;letter-spacing:0.04em;color:#8a6f45;text-transform:uppercase;margin-bottom:8px;">{{ m.num === 0 ? '巩固练习' : ('第 ' + m.num + ' 题') }}</div>
              <div style="font-size:16px;line-height:1.7;color:#1d1d1f;white-space:pre-wrap;">{{ m.text }}</div>
            </div>

            <div v-else-if="m.kind === 'answer'" style="align-self:flex-end;max-width:560px;background:#f1ece0;border-radius:16px;padding:16px 20px;font-size:15px;line-height:1.6;color:#1d1d1f;white-space:pre-wrap;">{{ m.text }}</div>

            <div v-else-if="m.kind === 'score'" style="align-self:center;width:100%;max-width:600px;background:rgba(0,0,0,0.02);border:1px solid rgba(0,0,0,0.06);border-radius:16px;padding:20px 24px;">
              <div style="display:flex;align-items:baseline;gap:6px;margin-bottom:10px;">
                <span style="font-size:28px;font-weight:700;color:#8a6f45;">{{ m.score }}</span>
                <span style="font-size:14px;color:#6e6e73;">/ 100</span>
              </div>
              <div style="font-size:14px;line-height:1.6;color:#48484a;margin-bottom:12px;">{{ m.feedback }}</div>
              <div style="display:flex;flex-wrap:wrap;gap:8px;">
                <span v-for="(pt, idx) in m.hit" :key="'h'+idx" style="font-size:12px;background:rgba(92,124,92,0.12);color:#4a6b4a;padding:4px 10px;border-radius:980px;">✓ {{ pt }}</span>
                <span v-for="(pt, idx) in m.missed" :key="'x'+idx" style="font-size:12px;background:rgba(192,82,63,0.1);color:#a8442f;padding:4px 10px;border-radius:980px;">{{ pt }}</span>
              </div>
            </div>

            <div v-else-if="m.kind === 'error'" style="align-self:center;background:rgba(192,82,63,0.08);border:1px solid rgba(192,82,63,0.2);color:#a8442f;border-radius:12px;padding:10px 16px;font-size:13px;">{{ m.text }}</div>
          </template>
        </div>
      </div>

      <div style="flex-shrink:0;border-top:1px solid rgba(0,0,0,0.08);background:#ffffff;padding:16px 40px;">
        <div style="max-width:680px;margin:0 auto;display:flex;align-items:flex-end;gap:12px;">
          <textarea
            v-model="answerText"
            @keydown.enter.exact.prevent="sendAnswer"
            :placeholder="waitingForAnswer ? '输入你的回答…' : '等待题目推送…'"
            style="flex:1;min-height:48px;max-height:140px;border:1px solid rgba(0,0,0,0.12);border-radius:14px;padding:12px 16px;font-size:15px;line-height:1.5;font-family:inherit;resize:none;outline:none;"
          ></textarea>
          <button @click="sendAnswer" :style="sendBtnStyle">发送</button>
          <span @click="quitInterview" style="font-size:13px;color:#6e6e73;cursor:pointer;white-space:nowrap;padding-bottom:14px;">结束面试</span>
        </div>
      </div>
    </div>

    <!-- Ended -->
    <div v-if="stage === 'ended'" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;">
      <span style="font-size:22px;font-weight:600;">面试已结束</span>
      <span style="font-size:15px;color:#6e6e73;">感谢参与本次模拟面试。</span>
      <button @click="restart" style="background:#1d1d1f;color:#fff;border:none;border-radius:980px;padding:14px 32px;font-size:15px;font-weight:600;cursor:pointer;margin-top:8px;">重新开始</button>
    </div>

    <!-- Report -->
    <div v-if="stage === 'report'" style="flex:1;overflow-y:auto;">
      <div style="max-width:720px;margin:0 auto;padding:72px 24px 100px;">
        <div style="font-size:13px;font-weight:600;letter-spacing:0.04em;color:#8a6f45;text-transform:uppercase;margin-bottom:12px;text-align:center;">评估报告</div>
        <h1 style="font-family:Georgia,'Songti SC',serif;font-size:38px;font-weight:600;text-align:center;margin:0 0 40px;">面试评估报告</h1>
        <template v-for="(blk, i) in reportBlocks" :key="i">
          <h1 v-if="blk.type === 'h1'" style="font-family:Georgia,'Songti SC',serif;font-size:28px;font-weight:600;margin:36px 0 12px;">{{ blk.text }}</h1>
          <h2 v-else-if="blk.type === 'h2'" style="font-family:Georgia,'Songti SC',serif;font-size:22px;font-weight:600;margin:32px 0 10px;">{{ blk.text }}</h2>
          <h3 v-else-if="blk.type === 'h3'" style="font-size:17px;font-weight:600;margin:24px 0 8px;color:#48484a;">{{ blk.text }}</h3>
          <div v-else-if="blk.type === 'li'" style="display:flex;gap:10px;margin-bottom:8px;padding-left:4px;">
            <span style="color:#8a6f45;">•</span>
            <span style="font-size:16px;line-height:1.75;color:#1d1d1f;">{{ blk.text }}</span>
          </div>
          <p v-else-if="blk.type === 'p'" style="font-size:16px;line-height:1.8;color:#1d1d1f;margin:0 0 16px;">{{ blk.text }}</p>
          <div v-else-if="blk.type === 'hr'" style="border-top:1px solid rgba(0,0,0,0.08);margin:32px 0;"></div>
        </template>
        <div style="text-align:center;margin-top:56px;">
          <button @click="restart" style="background:#1d1d1f;color:#fff;border:none;border-radius:980px;padding:14px 32px;font-size:15px;font-weight:600;cursor:pointer;">重新开始面试</button>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onBeforeUnmount } from 'vue'

const stage = ref('setup') // setup | connecting | live | report | ended
const jd = ref('')
const resume = ref('')
const userId = ref('web-' + Math.random().toString(36).slice(2, 8))
const wsUrl = ref(import.meta.env.VITE_WS_URL || 'ws://localhost:8085')
const showAdvanced = ref(false)
const connectError = ref('')
const messages = ref([])
const currentStepIndex = ref(-1)
const waitingForAnswer = ref(false)
const answerText = ref('')
const reportMd = ref('')
const transcriptRef = ref(null)

let ws = null

const canStart = computed(() => !!(jd.value.trim() && resume.value.trim()))
const canSend = computed(() => waitingForAnswer.value && !!answerText.value.trim())

const startBtnStyle = computed(() => ({
  marginTop: '20px', width: '100%', background: '#1d1d1f', color: '#fff', border: 'none',
  borderRadius: '980px', padding: '16px 0', fontSize: '17px', fontWeight: 600,
  cursor: canStart.value ? 'pointer' : 'not-allowed', opacity: canStart.value ? 1 : 0.4, transition: 'opacity .2s'
}))

const sendBtnStyle = computed(() => ({
  background: '#1d1d1f', color: '#fff', border: 'none', borderRadius: '980px',
  padding: '13px 22px', fontSize: '15px', fontWeight: 600,
  cursor: canSend.value ? 'pointer' : 'not-allowed', opacity: canSend.value ? 1 : 0.4
}))

const stepDefs = ['JD 解析', '简历匹配', '出题规划', '模拟问答', '薄弱巩固', '评估报告']
const stepperItems = computed(() => stepDefs.map((label, i) => {
  let color = '#c7c7cc', weight = 400
  if (i < currentStepIndex.value) { color = '#8a6f45'; weight = 500 }
  else if (i === currentStepIndex.value) { color = '#1d1d1f'; weight = 700 }
  return { label, style: { fontSize: '13px', color, fontWeight: weight } }
}))

watch(messages, async () => {
  await nextTick()
  if (transcriptRef.value) transcriptRef.value.scrollTop = transcriptRef.value.scrollHeight
}, { deep: true })

function pushMessage(m) {
  messages.value.push({ id: messages.value.length, ...m })
}

function buildWsUrl() {
  const base = (wsUrl.value || 'ws://localhost:8085').trim().replace(/\/$/, '')
  return base + '/ws?userId=' + encodeURIComponent(userId.value || 'web-guest')
}

function friendlyStageLabel(stageKey) {
  const map = {
    jd_analysis: '正在分析职位描述…', jd_analysis_done: 'JD 解析完成',
    resume_match: '正在比对简历与岗位要求…', resume_match_done: '简历匹配完成',
    question_plan: '正在规划面试题目…', rag_retrieval: '正在检索题库…',
    rag_retrieval_done: '题库检索完成', question_plan_done: '出题规划完成',
    interview: '模拟面试开始', interview_done: '模拟面试结束', terminated: '面试已终止',
    review_weak: '正在整理薄弱项…', review_weak_done: '薄弱项巩固完成',
    evaluation: '正在生成评估报告…', evaluation_done: '评估报告生成完成'
  }
  return map[stageKey] || stageKey
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

function onStart() {
  if (!canStart.value) return
  connectAndStart()
}

function connectAndStart() {
  stage.value = 'connecting'
  connectError.value = ''
  let socket
  try {
    socket = new WebSocket(buildWsUrl())
  } catch (e) {
    stage.value = 'setup'
    connectError.value = '无法创建连接，请检查地址格式'
    return
  }
  ws = socket
  socket.onmessage = (ev) => {
    let msg
    try { msg = JSON.parse(ev.data) } catch (e) { return }
    handleServerMessage(msg)
  }
  socket.onerror = () => {
    connectError.value = '连接失败，请确认后端服务正在运行'
  }
  socket.onclose = () => {
    if (stage.value === 'connecting') {
      stage.value = 'setup'
      connectError.value = '连接已断开，请确认后端服务地址与状态'
    }
  }
}

function handleServerMessage(msg) {
  if (msg.type === 'connected') {
    pushMessage({ kind: 'system', text: '已连接面试官，正在提交简历与 JD…' })
    ws.send(JSON.stringify({ type: 'start_interview', jd: jd.value, resume: resume.value }))
    stage.value = 'live'
  } else if (msg.type === 'stage_change') {
    currentStepIndex.value = Math.max(currentStepIndex.value, stepIndexForStage(msg.stage))
    pushMessage({ kind: 'system', text: msg.message || friendlyStageLabel(msg.stage) })
  } else if (msg.type === 'question') {
    pushMessage({ kind: 'question', num: msg.question_num, text: msg.content })
    waitingForAnswer.value = true
  } else if (msg.type === 'score') {
    pushMessage({ kind: 'score', score: msg.score, feedback: msg.feedback, hit: msg.key_points_hit || [], missed: msg.key_points_missed || [] })
  } else if (msg.type === 'report') {
    reportMd.value = msg.content
    stage.value = 'report'
  } else if (msg.type === 'error') {
    pushMessage({ kind: 'error', text: msg.message })
  } else if (msg.type === 'interview_complete') {
    if (stage.value !== 'report') stage.value = 'ended'
  }
}

function sendAnswer() {
  const text = answerText.value.trim()
  if (!text || !waitingForAnswer.value) return
  ws.send(JSON.stringify({ type: 'answer', content: text }))
  pushMessage({ kind: 'answer', text })
  answerText.value = ''
  waitingForAnswer.value = false
}

function quitInterview() {
  if (ws) ws.send(JSON.stringify({ type: 'quit_interview' }))
  pushMessage({ kind: 'system', text: '已发送结束面试请求…' })
}

function restart() {
  if (ws) { try { ws.close() } catch (e) {} ws = null }
  stage.value = 'setup'
  messages.value = []
  reportMd.value = ''
  connectError.value = ''
  waitingForAnswer.value = false
  answerText.value = ''
  currentStepIndex.value = -1
}

function cleanMd(t) {
  return t.replace(/\*\*/g, '').replace(/`/g, '').trim()
}

function parseMarkdown(md) {
  if (!md) return []
  const lines = md.split('\n')
  const blocks = []
  let para = []
  const flushPara = () => { if (para.length) { blocks.push({ type: 'p', text: para.join(' ').trim() }); para = [] } }
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

const reportBlocks = computed(() => parseMarkdown(reportMd.value))

onBeforeUnmount(() => {
  if (ws) { try { ws.close() } catch (e) {} }
})
</script>

<style>
@keyframes pulseDot { 0%, 100% { opacity: 1; } 50% { opacity: 0.25; } }
</style>
