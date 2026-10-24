# Uptime Kuma APP

一款面向自托管 [Uptime Kuma](https://github.com/louislam/uptime-kuma) 实例的 Flutter 客户端。读取公开状态页、查看心跳、在监控状态变化时收到原生推送通知——如需，也可以登录后在手机上管理整个实例：监控器、通知渠道和事件。

应用包名：`com.zakoflare.uptime_kuma_app`。

> **English README**: [README.md](./README.md)

---

## 功能一览

| 分类 | 功能 |
|---|---|
| 实例 | 支持不限数量的 Uptime Kuma 服务器，切换自如，每实例独立缓存。支持两种模式：**仅监控**（公开状态页 URL）或**移动管理**（用户名 + 密码 → Socket.IO 会话）。 |
| 引导页 | 首次启动介绍两种实例模式；不捆绑任何演示数据。 |
| 状态 | 总体健康状态横幅、按组显示监控器、60 条心跳记录、24h/30d/90d 可用率、响应时间、TLS 证书到期提醒、维保中与事件横幅。 |
| 详情 | **点击/拖动读取任意采样点时间戳与延迟**的响应时间图表、可用率时段、状态变更时间线、证书状态。 |
| 管理 | 添加 / 编辑 / 删除监控器（HTTP、关键字、TCP、端口、Ping、DNS、分组），暂停与恢复、按监控器绑定通知渠道、创建与置顶事件、管理通知提供商（Telegram、Discord、Slack、Gotify、ntfy、Webhook、飞书、钉钉、企业微信、PushPlus、SMTP）、发送测试通知。 |
| 告警 | 监控器状态 `up → down` 与 `down → up` 时触发本地通知，包含监控器名称、故障状态、**开始时间**、累计宕机时长、实例名及最后一条错误信息。 |
| 声音 | 5 种内置合成音调、应用内预览，**支持上传自定义音频**（`wav/mp3/ogg/m4a/aac/flac`）。 |
| 后台 | Android WorkManager 每 15 分钟定期检查，应用关闭时也能收到告警。 |
| 主题 | 浅色 / 深色 / 跟随系统，9 种主题色。 |
| 界面风格 | 两种界面风格：**Uptime Kuma**（圆角卡片、胶囊徽章）和 **Tencent Cloud**（直角、细线边框、紧凑行）。 |
| 外观 | 支持自定义照片背景（可调透明度与模糊）；可选**长名称截断**（8–40 字符），避免滚动时列表重排。 |
| 图标 | 4 个启动器图标，支持运行时切换（official + 三种换色版）。不支持上传自定义图标。 |
| 隐私 | 可开关使用报告、DNS-over-HTTPS（支持**自定义端点与端口**，任意 `?name=` JSON 解析器）、自定义 User-Agent。 |
| 关于 | 版本号、联系方式、项目链接、APK 签名证书 SHA-256。 |
| 存储 | 缓存大小一目了然，一键清理；设置数据不受影响。 |
| 语言 | 简体中文 / English，运行时随时切换。 |

---

## 数据获取方式

### 监控模式 —— 公开状态页，无需凭证

```
GET {base}/api/status-page/{slug}
GET {base}/api/status-page/heartbeat/{slug}
```

`{slug}` 是公开状态页 URL 中 `/status/` 后的路径段。添加实例时会自动解析完整 URL 并填充 slug。

### 管理模式 —— Socket.IO

Uptime Kuma **不提供管理用 REST API**。API Key（`uk1_…`）仅被 `/metrics` 接口接受，因此应用不虚构 API Key 的管理能力——该字段为可选项，仅标记为 `/metrics` 凭证。

真正的管理操作通过 Web UI 使用的同一 Socket.IO 通道进行：

```
login            {username, password, token?}  → {ok, token} | {tokenRequired:true}
loginByToken     {token}                       → JWT，会话可在重启后保持
getMonitorList / add / editMonitor / deleteMonitor / pauseMonitor / resumeMonitor
addNotification / deleteNotification / testNotification
addStatusPage / postIncident / unpinIncident / clearEvents
```

服务器推送：`monitorList` 与 `statusPageList` 为**以 id 为键的对象**，`notificationList` 为普通数组，`heartbeatList(id, list, overwrite)` 和 `uptime(id, period, percent)` 携带多个参数。仅持久化 JWT；密码在登录后立即丢弃。

**Socket.IO 调试细节（针对 Kuma 2.5.6，已验证）：**

| 细节 | 客户端处理 |
|---|---|
| `socket_io_client` 通过轮询无法完成握手 | transports 顺序为 `['websocket', 'polling']` |
| 库会将 `List` 参数展开为多个位置参数 | 多参数事件以列表形式发送：`deleteMonitor` 需 `[id, deleteChildren]`，`addNotification` 需 `[notification, id]` |
| `testNotification` 接受**整个通知对象**，而非 id | 直接回显 `notificationList` 中的行 |
| 2.x 中事件按状态页 **slug** 寻址，服务器强制 `pin = 1` | 事件表单选择 slug，没有"图钉"开关可以撒谎 |
| `statusPageList` 仅在登录时推送一次 | 变更后重新发送 `loginByToken` 以回放列表 |
| 部分事件（`setup`、`loginRequired`）**无**载荷 | `onAny` 处理器的第二个参数为可选，否则抛异常 |
| `add` 载荷必须携带 `conditions`、`rabbitmqNodes`、`kafkaProducerBrokers`、`kafkaProducerSaslOptions` | 始终发送空数组：服务器 `JSON.stringify` 后才插入 |

Uptime Kuma 将心跳时间戳序列化为 `yyyy-MM-dd HH:mm:ss.SSS` **UTC 且无时区标识**；`Heartbeat.parseKumaTime` 将其视为 UTC，界面再转换为本地时间。

---

## 项目结构

```
lib/
  core/
    l10n/        手写 zh/en 字符串（无需代码生成）
    theme/       AppTokens ThemeExtension + ThemeData 工厂
    utils/       格式化、状态颜色、标签映射
    widgets/     AppCard、HeartbeatBar、PingChart、AppBackground、RemoteIcon
  data/
    api/         UkApi（状态页）、UkSocket（Socket.IO 管理）
    net/         DoH 解析器 + 共享 HttpClient 工厂
    cache/       按实例的 JSON 快照缓存
    models/      ServerConfig、Monitor、Heartbeat、StatusSnapshot 及管理端模型
  services/      设置、通知、后端检查、图标切换、
                 音频库、自定义音频发布、使用报告
  state/         AppState（偏好 + 实例）、StatusController（轮询 +
                 状态转换）、AdminController（会话 + CRUD）
  features/      guide、dashboard、monitor detail、servers、admin/*、settings/*
tool/            图标 + 音频生成器、源码打包器
```

---

## 值得了解的设计决策

**主题是 `ThemeExtension`，不是一堆条件分支。** `AppTokens` 承载圆角、边框、阴影、内边距和语义化状态颜色。组件调用 `context.tk.radiusMd`；在圆角风格和直角风格之间切换只需替换 token 集，无需在组件层分支。主题色和亮度通过同一工厂流入。

**通知是边沿触发，而非电平触发。** 告警仅在监控器状态与上一次观察结果不同时触发。冷启动首次加载建立基线并保持静默——否则每次启动都会对已故障的监控器重复告警。基线按实例持久化，后台检查从前台停止的位置继续。

**Android 在渠道创建时缓存通知音频。** 因此每种音调使用独立的渠道 ID（`uk_alerts_<resource>`、`uk_alerts_custom_<n>`）。切换音调时切换渠道；ID 不可重用。

**上传的音频必须发布到媒体存储。** 通知音频由 `system_server` 打开，无法读取 `/data/data/<pkg>`。选定文件被复制到共享的 *Notifications* 集合并以 `content://media/…`（`UriAndroidNotificationSound`）引用。Android 9 及以下需要 `WRITE_EXTERNAL_STORAGE`，在需要时申请；若被拒绝则提示用户并回退到内置音调，而非指向不可读的 `file://` 路径。

**启动器图标仅限预设。** `activity-alias` 在 APK 内置图标之间切换，切换即时且无需重装。用户位图**无法**替换已安装应用的主图标——"快捷方式"方案只会添加一个与主图标并列的第二个图标，看起来像是"上传失败了"，因此已移除上传功能。

---

## 外观预览

设置页刻意不实时显示效果（详见下述闪烁问题），因此 UI 透明度和毛玻璃滑块在没有内容可穿透的情况下看不到任何效果。外观页链接到**实时预览**——真实的头部和卡片覆盖在用户自己的照片上，三个相关控件内联展示，让用户在真实视觉中做决定，而非靠猜测。

---

## 集合与分享码

实例可以组成**集合（Collection）**。这是应用本地的账本记录（`ServerConfig.collectionId`）：成员在手机上合并为**一个状态面板**，按列表顺序排列，组标题以实例名为前缀。监控器 id 按实例偏移 10,000,000，因此两个 id 都从 1 开始的服务器在 `heartbeats` / `uptime` 中不会冲突。集合信息不向上游发送，公开状态页不受影响。

集合仅合并公开状态页——管理会话绑定到单一实例，不可复用。

配置以 `uptimekuma://` 链接形式传输（base64url JSON，无 padding）：

```
uptimekuma://instance/<payload>     单个实例
uptimekuma://collection/<payload>   整个集合
```

凭证被故意排除——API Key 和会话 JWT 均未编码，泄露剪贴板不会导致管理权限被冒用。导入管理实例时需重新输入密码。

---

## 构建

> （暂无构建说明，TODO）
