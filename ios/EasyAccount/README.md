# EasyAccount（SwiftUI）

按 Web 端 `EasyAccountAgent` 设计复现的 **智能记账** iOS 客户端，仅包含记账模块（登录/注册、会话恢复、WebSocket 对话），不包含 Interview / Playground。

## 要求

- macOS + Xcode 15+
- iOS 17.0+
- 可访问的 `easyaccount-agent` 后端（HTTP + WebSocket）

## 打开与运行

1. 用 Xcode 打开 `EasyAccount.xcodeproj`
2. 选择模拟器或真机
3. 如需签名，在 Target → Signing & Capabilities 中选择你的 Team
4. Run（⌘R）

默认连接：

- HTTP：`http://127.0.0.1:8088`
- WS：`ws://127.0.0.1:8088`

可在登录页「连接设置」中修改。模拟器访问本机后端请用 `127.0.0.1`；真机请改为电脑局域网 IP。

## 与 Web 端对齐的能力

| 能力 | 说明 |
|------|------|
| 登录 / 注册 | `POST /api/auth/login`、`/api/auth/register` |
| 会话恢复 | `GET /api/auth/me` + UserDefaults 持久化 token |
| 退出 | `POST /api/auth/logout` |
| 对话 | `WS /ws?token=…`，协议与 Web 一致（`chat` / `connected` / `message_delta` / `message_end` / `error`） |
| 重连 | 连接失败与断线后校验会话并退避重连 |

## 目录

```
EasyAccount/
  EasyAccountApp.swift
  AppConfig.swift
  Models/
  Services/
  ViewModels/
  Views/
  Theme/
  Assets.xcassets/
  Info.plist
```
