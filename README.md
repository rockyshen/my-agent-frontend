# my-agent-frontend

基于设计稿生成的 Vue 3 + Vite 工程：左侧 Agent 列表，右侧激活对应 Agent 的对话界面（WebSocket 实时连接）。

## 使用

```bash
npm install
npm run dev
```

默认对接后端 `ws://localhost:8085`（开发）或 `.env.production` 中的 `VITE_WS_URL`（生产构建），
可在界面高级设置里修改地址与 userId。

## 结构

- `src/App.vue` — 整体左右布局、Agent 列表与选中态
- `src/components/InterviewAgent.vue` — 面试模拟 Agent 对话界面，完整实现 JD/简历提交、
  分阶段进度、逐题问答与评分、最终评估报告渲染
- 新增 Agent：在 `App.vue` 的 `agents` 列表中新增一项（`available: true`），并新建对应组件，
  在右侧面板按 `selected` 值挂载即可。
