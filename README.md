# my-agent-frontend

基于设计稿生成的 Vue 3 + Vite 工程：左侧 Agent 列表，右侧激活对应 Agent 的对话界面（WebSocket 实时连接）。

## 使用

```bash
npm install
npm run dev
```

侧栏两个 Agent：
- **面试模拟 Agent** → 稳定版 `interview-agent`（生产 `ws://118.25.46.207:6085`）
- **Playground 实验** → `SpringAIAlibaba-playground`（生产 `ws://118.25.46.207:6087`）

环境变量见 `.env.development` / `.env.production`，也可在界面高级设置里修改。

## 结构

- `src/App.vue` — 整体左右布局、Agent 列表与选中态
- `src/components/InterviewAgent.vue` — 面试模拟 Agent 对话界面，完整实现 JD/简历提交、
  分阶段进度、逐题问答与评分、最终评估报告渲染
- 新增 Agent：在 `App.vue` 的 `agents` 列表中新增一项，并新建对应组件，
  在右侧面板按 `selected` 值挂载即可。
