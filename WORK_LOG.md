# 二人聊天 APP — 工作日志（Work Log）

> 项目路径：`D:/chat_app`  
> 后端路径：`/opt/chat-server`（服务器 116.62.198.239）  
> 最后更新：2026-07-18

---

## 一、项目架构总览

### 1.1 前端（Flutter）目录结构

```
lib/
├── main.dart                      # 入口文件
├── app.dart                       # 应用根组件（路由 + Provider 注入）
├── config/
│   └── api_config.dart            # 服务器地址配置（IP + 端口）
├── models/                        # 数据模型层（零依赖）
│   ├── message.dart               # 消息模型（含类型、附件、撤回等）
│   └── user.dart                  # 用户模型
├── providers/                     # 状态管理层
│   └── chat_provider.dart         # 聊天核心状态（消息、发送、接收、未读、在线等）
├── services/                      # 业务逻辑层（单向依赖）
│   ├── auth_service.dart          # 认证：登录/登出/Token 管理
│   ├── api_service.dart           # HTTP API：消息、搜索、文件上传、位置
│   ├── socket_service.dart        # Socket.io：实时通信、消息推送
│   ├── location_service.dart      # 位置：GPS 获取、定时上传
│   └── sticker_service.dart       # 表情包：本地存储/收藏
├── screens/                       # 页面层
│   ├── login_screen.dart          # 登录页
│   ├── chat_list_screen.dart      # 聊天列表（会话列表）
│   ├── chat_detail_screen.dart    # 聊天详情（消息列表 + 输入栏）
│   ├── search_screen.dart         # 聊天记录搜索
│   ├── location_share_screen.dart # 位置共享（地图 + 轨迹）
│   └── video_player_screen.dart   # 视频播放器
└── widgets/                       # 纯 UI 组件层（通过回调解耦）
    ├── chat_input.dart            # 聊天输入栏（文本/语音/图片/视频/文件/位置）
    ├── message_bubble.dart        # 消息气泡（支持文本/图片/视频/文件/语音）
    ├── emoji_picker.dart          # Emoji 选择器
    ├── sticker_picker.dart        # 表情包选择器
    ├── image_viewer.dart          # 大图查看器
    └── user_avatar.dart           # 用户头像
```

### 1.2 后端（Node.js）目录结构

```
/opt/chat-server/
├── server.js              # Express 主服务（路由 + Socket.io + 数据库操作）
├── package.json           # 依赖（express, socket.io, multer, ali-oss）
├── ecosystem.config.js    # PM2 进程管理配置
├── locations.json         # 位置数据存储（JSON 文件）
├── messages.json          # 消息数据存储（JSON 文件）
├── users.json             # 用户数据存储（JSON 文件）
├── stickers.json          # 表情包数据存储（JSON 文件）
├── uploads/               # 本地上传文件缓存
└── public/                # 网页版静态资源
```

---

## 二、模块化分析

### 2.1 依赖关系图

```
models/ ─────┐
config/ ─────┤
             │    ┌── AuthService
             │    │      ↑
             │    ├── ApiService ─────┐
             │    ├── SocketService ──┤──→ ChatProvider
             │    │      ↑           │
             │    ├── LocationService│
             │    └── StickerService │
             │                       │
widgets/ ────┘                       └── screens/
```

**关键规则：**
- `models/` 和 `config/` 不依赖任何其他层
- `services/` 只依赖 `models/`、`config/` 和同级 `AuthService`（单向）
- `providers/` 聚合多个 `services/`，管理 UI 状态
- `widgets/` 不依赖 `services/`，只通过回调与外部通信
- `screens/` 组合 `widgets/` + `providers/`

### 2.2 各模块独立性评分

| 模块 | 职责 | 耦合度 | 独立性 | 说明 |
|------|------|--------|--------|------|
| `AuthService` | 认证/Token | 低 | ✅ 高 | 只被依赖，不依赖其他 Service |
| `ApiService` | HTTP 请求 | 低 | ✅ 高 | 仅依赖 AuthService 获取 token |
| `SocketService` | 实时通信 | 低 | ✅ 高 | 仅依赖 AuthService，对外暴露 Stream |
| `LocationService` | GPS/位置 | 中 | ⚠️ 中 | 依赖 SocketService 做实时推送，已用公共方法解耦 |
| `StickerService` | 本地表情包 | 低 | ✅ 高 | 完全独立，只操作本地文件 |
| `ChatProvider` | 状态管理 | 高 | ❌ 低 | "上帝类"，管理了消息/发送/接收/未读/在线/撤回等所有状态 |
| `ChatInput` | 输入栏 | 极低 | ✅ 高 | 纯回调驱动，不引用任何 Service |
| `MessageBubble` | 消息气泡 | 极低 | ✅ 高 | 纯展示组件 |

### 2.3 目前存在的问题

1. **ChatProvider 过于臃肿**（380+ 行）
   - 管理：消息列表、发送消息、接收消息、上传状态、打字状态、在线状态、消息撤回、未读计数、清除状态
   - 建议拆分：`MessageProvider` + `TypingProvider` + `OnlineProvider` + `UnreadProvider`

2. **ChatDetailScreen 过长**（370+ 行）
   - 包含：发送文本/图片/视频/文件/语音/表情包、录音逻辑、消息菜单、撤回逻辑
   - 建议拆分：将发送逻辑提取到独立 Controller

3. **后端 server.js 是单文件**（400+ 行）
   - 包含：Express 路由、Socket.io 事件、数据库读写、OSS 上传、文件系统操作
   - 建议拆分：`routes/` + `services/` + `models/` 目录

4. **缺乏接口抽象层**
   - Service 之间直接引用具体实现，没有 Interface
   - 对两个人用的项目来说这不是大问题，但后期如果要换网络库或换地图 SDK，需要改多处

### 2.4 优化建议（按优先级排序）

| 优先级 | 优化项 | 预期收益 |
|--------|--------|----------|
| P1 | 将后端 `server.js` 拆分为 `routes/` + `controllers/` + `services/` | 最大，后端维护难度显著降低 |
| P2 | 将 `ChatProvider` 拆分为 3-4 个独立 Provider | 中高，前端状态管理更清晰 |
| P3 | 将 `ChatDetailScreen` 中的发送逻辑提取到 `MessageController` | 中，页面代码减少 50% |
| P4 | 为 Services 添加抽象接口（如 `IAuthService`） | 低，现阶段过度设计 |

---

## 三、功能实现记录（按时间线）

| 日期 | 功能 | 涉及文件 | 状态 |
|------|------|----------|------|
| 07-17 | 环境搭建：JDK 17 + Flutter SDK + Android SDK | 系统环境变量 | ✅ 完成 |
| 07-17 | 后端部署：Node.js + Express + Socket.io | `/opt/chat-server/server.js` | ✅ 完成 |
| 07-17 | 后端部署：网页版聊天页面 | `/opt/chat-server/public/index.html` | ✅ 完成 |
| 07-17 | Flutter 项目创建 + 16 个文件 | `D:/chat_app/lib/` | ✅ 完成 |
| 07-17 | APK 首次编译成功 | `build/app/outputs/flutter-apk/app-release.apk` | ✅ 完成 |
| 07-17 | 修复：登录时用户名/密码编码问题 | `auth_service.dart` | ✅ 完成 |
| 07-18 | 修复：自己发消息不能立刻显示 | `chat_provider.dart` | ✅ 完成 |
| 07-18 | 图片选择 + 发送 + 渲染 | `chat_detail_screen.dart`, `message_bubble.dart` | ✅ 完成 |
| 07-18 | 后端：OSS 上传接口 | `server.js` | ✅ 完成 |
| 07-18 | 聊天记录搜索 | `search_screen.dart`, `api_service.dart` | ✅ 完成 |
| 07-18 | 视频发送 + 播放 | `chat_detail_screen.dart`, `video_player_screen.dart` | ✅ 完成 |
| 07-18 | PDF/文件发送 | `chat_detail_screen.dart`, `message_bubble.dart` | ✅ 完成 |
| 07-18 | 自定义表情包（本地收藏 + Emoji） | `sticker_service.dart`, `sticker_picker.dart`, `emoji_picker.dart` | ✅ 完成 |
| 07-18 | 语音消息（长按录音） | `chat_detail_screen.dart`, `chat_input.dart` | ✅ 完成 |
| 07-18 | 消息撤回（2分钟内） | `chat_provider.dart`, `server.js` | ✅ 完成 |
| 07-18 | 切换账号状态清理 | `chat_provider.dart`, `auth_service.dart` | ✅ 完成 |
| 07-18 | 应用图标红点 + 应用内未读红点 | `chat_list_screen.dart`, `chat_provider.dart` | ✅ 完成 |
| 07-18 | 实时位置共享 + 轨迹记录（腾讯地图） | `location_service.dart`, `location_share_screen.dart`, `server.js` | ✅ 完成 |
| 07-18 | **视频通话（P2P WebRTC）** | `webrtc_service.dart`, `video_call_screen.dart`, `socket/handlers.js`, `socket_service.dart`, `app.dart` | ✅ 完成 |
| 07-18 | **iOS 系统适配** | `ios/Podfile`, `ios/Runner/Info.plist` | ✅ 完成 |

---

## 四、技术栈清单

| 层级 | 技术 | 版本 | 用途 |
|------|------|------|------|
| 前端框架 | Flutter | 3.19.0 | 跨平台 APP |
| 状态管理 | Provider | 6.1.1 | 状态共享 |
| 网络 | http + socket_io_client | 1.6.0 / 2.0.3 | HTTP + WebSocket |
| 定位 | geolocator | 10.1.1 | GPS 获取 |
| 地图 | flutter_map + latlong2 | 6.2.1 / 0.9.1 | 位置共享地图 |
| 图片/视频 | image_picker + video_player | 1.1.2 / 2.9.5 | 媒体选择/播放 |
| 文件 | file_picker | 6.2.1 | 文件选择 |
| 录音 | record | 4.4.4 | 语音录制 |
| 本地存储 | shared_preferences | 2.3.3 | Token/用户缓存 |
| 本地文件 | path_provider | 2.1.5 | 应用目录访问 |
| 后端框架 | Node.js + Express | 18.x / 4.x | API 服务 |
| 实时通信 | Socket.io | 4.x | 消息推送 |
| 对象存储 | 阿里云 OSS | - | 文件上传 |
| 视频通话 | `flutter_webrtc` | 0.10.8 | 点对点视频通话 |
| 服务器管理 | 1Panel | 1.10.26 | 服务器面板 |
| 云服务 | 阿里云轻量服务器 | 2vCPU 1GB | 部署后端 |

---

## 五、待办功能（Backlog）

| 优先级 | 功能 | 说明 |
|--------|------|------|
| P1 | 视频通话 | 点对点视频聊天 |
| P2 | 消息推送通知 | 红点提醒（已确定不做弹窗） |
| P3 | 相册访问优化 | 接入系统相册选择器（原生联动） |
| P4 | 后端模块化重构 | 拆分 `server.js` 为路由/控制器/服务层 |
| P5 | 鸿蒙/鸿蒙 NEXT 适配 | 需要调研 Flutter 对鸿蒙的支持 |
| P6 | 聊天记录备份/导出 | 支持导出为 JSON 或文件 |

---

## 六、编译与部署记录

| 操作 | 命令 | 路径 |
|------|------|------|
| 编译 APK | `flutter build apk --release` | `D:/chat_app` |
| 输出 APK | `build/app/outputs/flutter-apk/app-release.apk` | 最新：87.6MB（含 WebRTC） |
| 重启后端 | `pm2 restart chat-server` | `116.62.198.239` |
| 后端日志 | `pm2 logs chat-server` | 服务器 |
| 服务器管理 | `http://116.62.198.239:8090` | 1Panel 面板 |

---

*本日志由 AI 助手整理，如有遗漏或错误，请随时补充修正。*
