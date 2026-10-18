# Uptime Kuma Mobile

A Flutter client for self-hosted [Uptime Kuma](https://github.com/louislam/uptime-kuma)
instances. Read a public status page, watch heartbeats, get native alerts when a
monitor changes state — and, if you want, log in and manage the whole instance
from the phone: monitors, notifications and incidents.

Packaged as `com.zakoflare.uptime_kuma_app`.

## What it does

| Area | Behaviour |
| --- | --- |
| Instances | Unlimited Uptime Kuma servers, switchable, each with its own cache. Two modes: **monitor-only** (public status page URL) or **mobile management** (username + password → Socket.IO session). |
| Onboarding | First launch teaches the two instance modes; no demo data is bundled. |
| Status | Overall health banner, grouped monitors, 60-check heartbeat strips, 24h/30d/90d uptime, response time, TLS expiry, active-maintenance and incident banners. |
| Detail | Response-time chart with **tap/drag to read any sample's timestamp and latency**, uptime windows, state-change timeline, certificate state. |
| Management | Add / edit / delete monitors (HTTP, keyword, TCP, port, ping, DNS, group), pause & resume, per-monitor notification binding, create & pin incidents, manage notification providers (Telegram, Discord, Slack, Gotify, ntfy, webhook, Lark, DingTalk, ServerChan, PushPlus, SMTP), send test notifications. |
| Alerts | Local notifications on `up → down` and `down → up`, containing monitor name, fault status, **start time**, elapsed downtime, instance name and the last error message. |
| Sound | 5 synthesised bundled tones, in-app preview, plus **upload your own** (`wav/mp3/ogg/m4a/aac/flac`). |
| Background | Android WorkManager periodic check every 15 min, so alerts arrive with the app closed. |
| Theme | Light / dark / follow-system, 9 accent colours. |
| Layout | Two interface styles: *Uptime Kuma* (rounded cards, pill badges) and *Tencent Cloud* (square corners, hairline borders, dense rows). |
| Appearance | Custom photo background with opacity and blur; optional **long-name clamping** (8–40 chars) so a scrolling row can never reflow the list. |
| Icon | 4 launcher icons switchable at runtime via `activity-alias` (official + three recolours). Uploads are intentionally not offered — see below. |
| Privacy | Usage-report toggle, DNS-over-HTTPS toggle with a **custom endpoint and port** (any `?name=` JSON resolver), custom User-Agent. |
| About | Version, contact, project links, APK signing-certificate SHA-256. |
| Storage | Cache size readout and one-tap clear; settings survive. |
| Language | 简体中文 / English, switchable at runtime. |

## How the data is fetched

### Monitor mode — public status page, no credentials

```
GET {base}/api/status-page/{slug}
GET {base}/api/status-page/heartbeat/{slug}
```

`{slug}` is the segment after `/status/` in your public page URL. The add-instance
form parses full URLs (`https://host/status/main`) and fills the slug in.

### Management mode — Socket.IO

Uptime Kuma exposes **no administrative REST API**. The API key (`uk1_…`) is only
accepted by `apiAuth`, and `apiAuth` guards exactly one route: `/metrics`. So the
app does not pretend otherwise — the key field is optional and labelled as a
`/metrics` credential only.

Real management goes through the same Socket.IO channel the web UI uses:

```
login            {username, password, token?}  → {ok, token} | {tokenRequired:true}
loginByToken     {token}                       → JWT, so the session survives restarts
getMonitorList / add / editMonitor / deleteMonitor / pauseMonitor / resumeMonitor
addNotification / deleteNotification / testNotification
addStatusPage / postIncident / unpinIncident / clearEvents
```

Server pushes: `monitorList` and `statusPageList` are **objects keyed by id**,
`notificationList` is a plain array, `heartbeatList(id, list, overwrite)` and
`uptime(id, period, percent)` carry several arguments. Only the JWT is
persisted; the password is discarded right after login.

A few protocol details that cost real debugging time (all verified against a
Kuma 2.5.6 container, see `test/admin_e2e_test.dart`):

| Quirk | What the client does |
| --- | --- |
| `socket_io_client` never finishes the handshake over long-polling | transports are `['websocket', 'polling']`, in that order |
| The library spreads a `List` payload into several positional arguments | multi-argument events are emitted as lists: `deleteMonitor` needs `[id, deleteChildren]`, `addNotification` needs `[notification, id]`, `postIncident` needs `[slug, incident]`, `setup` needs `[username, password]` |
| `testNotification` takes the **notification object**, not an id | the row from `notificationList` is echoed back |
| Incidents are addressed by status-page **slug** in 2.x, and the server forces `pin = 1` | the event form picks a slug; there is no "pin" switch to lie about |
| `statusPageList` is only pushed on login — `addStatusPage` does not re-push it | a mutation re-emits `loginByToken` to replay the list |
| Some events (`setup`, `loginRequired`) carry **no** payload | the `onAny` handler's second parameter is optional, otherwise those events throw |
| The `add` payload must carry `conditions`, `rabbitmqNodes`, `kafkaProducerBrokers` and `kafkaProducerSaslOptions` | they are always sent as empty arrays: the server `JSON.stringify`s them before insert |

Uptime Kuma serialises heartbeat timestamps as `yyyy-MM-dd HH:mm:ss.SSS` **in UTC
with no timezone marker**; `Heartbeat.parseKumaTime` treats them as UTC and the UI
converts to local time.

## Project layout

```
lib/
  core/
    l10n/        hand-written zh/en strings (no codegen step)
    theme/       AppTokens ThemeExtension + ThemeData factory
    utils/       formatting, status colours, label mapping
    widgets/     AppCard, HeartbeatBar, PingChart, AppBackground, RemoteIcon
  data/
    api/         UkApi (status page), UkSocket (Socket.IO admin)
    net/         DoH resolver + shared HttpClient factory
    cache/       per-instance JSON snapshot cache
    models/      ServerConfig, Monitor, Heartbeat, StatusSnapshot, admin models
  services/      settings, notifications, background checks, icon switching,
                 sound library, custom-sound publishing, usage report
  state/         AppState (prefs + instances), StatusController (polling +
                 transitions), AdminController (session + CRUD)
  features/      guide, dashboard, monitor detail, servers, admin/*, settings/*
tool/            icon + sound generators, source packer
```

### Design decisions worth knowing

**Theme is a `ThemeExtension`, not a set of conditionals.** `AppTokens` carries
radii, borders, shadows, paddings and semantic status colours. Widgets read
`context.tk.radiusMd`; switching between the rounded and square styles swaps the
token set, so no widget branches on style. Accent colour and brightness flow into
the same factory.

**Notifications are edge-triggered, not level-triggered.** Alerts fire only when a
monitor's status differs from the previous observation. The first load of a cold
start establishes a baseline and stays silent — otherwise every app launch would
re-alert on an already-failing monitor. The baseline is persisted per instance, so
background checks pick up where the foreground left off.

**Android caches the audio of a notification channel at creation time**, so each
tone gets its own channel id (`uk_alerts_<resource>`, `uk_alerts_custom_<n>`).
Changing the tone switches channels; the id must not be reused.

**Uploaded tones have to be published to the media store.** Notification audio is
opened by `system_server`, which cannot read `/data/data/<pkg>`. The chosen file is
copied into the shared *Notifications* collection and referenced as
`content://media/…` (`UriAndroidNotificationSound`). On Android 9 and below this
needs `WRITE_EXTERNAL_STORAGE`, requested on demand; if it is refused the app says
so and falls back to the bundled tone instead of pointing at an unreadable
`file://` path.

**Launcher icons are preset only.** `activity-alias` swaps between icons baked
into the APK, so switching is instant and needs no reinstall. A user bitmap
*can't* replace the launcher icon of an installed package — the pinned-shortcut
workaround only adds a second icon next to the app, which read as "the upload
didn't work", so uploading was dropped.

## Appearance preview

Settings pages are opaque on purpose (see the flicker notes below), which means
the UI-opacity and frosted-glass sliders have nothing visible behind them. The
appearance page therefore links to a **live preview** — a real header and real
cards painted over the user's own photo, with the three relevant controls inline
so the decision is made by looking rather than guessing.

## Collections and share codes

Instances can be grouped into a **collection**. It is app-local bookkeeping in
`ServerConfig.collectionId`: members are merged into **one status board** on the
phone, in list order, with their group titles prefixed by instance name. Monitor
ids are offset by 10,000,000 per instance so two servers whose ids both start at
1 cannot collide in `heartbeats` / `uptime`. Nothing is sent upstream, so the
published status page is untouched.

Collections only merge public status pages — a management session is bound to a
single instance and cannot be multiplexed.

Configurations travel as `uptimekuma://` links (base64url JSON, no padding):

```
uptimekuma://instance/<payload>     one instance
uptimekuma://collection/<payload>   a whole collection
```

Credentials are deliberately excluded — neither the API key nor the session JWT
is encoded, so a leaked clipboard cannot grant management access. An imported
management instance asks for a password again.

## Build

Requires Flutter 3.47+ and an Android SDK with build-tools 36 (`minSdk 23`).

```bash
flutter pub get
flutter build apk --release                 # universal
flutter build apk --release --split-per-abi # per-ABI
```

Regenerating bundled assets:

```bash
python tool/make_sounds.py       # assets/sounds/*.wav + res/raw/*.wav
python tool/make_brand_icons.py  # icons derived from Uptime Kuma's official SVG
```

`make_brand_icons.py` reads `assets/images/icon_official.png` (white field,
green Kuma circle) and writes the legacy `mipmap-*` bitmaps, the recoloured
previews, and an **adaptive icon** per colour way (`mipmap-anydpi-v26/*.xml`
with a white `uk_bg_white` background and the circle as foreground). Without the
adaptive descriptor Android 8+ treats the bitmap as a legacy icon and shrinks it
inside its own mask, which reads as "the icon is too small / still the old one".

## Tests

```bash
flutter analyze   # must stay clean
flutter test
```

`test/parsing_test.dart` covers URL/slug parsing, UTC heartbeat parsing, status
aggregation and JSON round-tripping. `test/widget_smoke_test.dart` renders the
shared widgets across both styles × both brightnesses × both locales.
`test/dashboard_render_test.dart` renders the real dashboard at 360 px and 412 px
for both UI styles, in dark mode and English, and asserts the outage headline —
it catches overflows and provider regressions without touching the network.
`test/admin_models_test.dart` pins the Socket.IO payload format (notification
map, status-code list, server-owned fields surviving an edit).
`test/api_live_test.dart` hits a real instance and skips when offline.

`test/admin_e2e_test.dart` drives the whole management protocol against a
throwaway container and is skipped unless you point it at one:

```bash
docker run -d --name uk-test -p 3001:3001 \
  -e UPTIME_KUMA_DB_TYPE=sqlite louislam/uptime-kuma:2
flutter test test/admin_e2e_test.dart --dart-define=E2E_BASE=http://127.0.0.1:3001
```

It creates the first admin account, logs in, adds a monitor, edits it, pauses and
resumes it, adds and deletes a notification provider, creates a status page,
posts and unpins an incident, then deletes the monitor.

## Limits

- WorkManager's minimum periodic interval is 15 minutes; faster alerting requires
  a foreground service.
- Management mode needs an account with admin rights on the instance. Instances
  with 2FA prompt for the one-time code at login.
- Runtime icon switching and custom-sound publishing are Android only (iOS needs
  alternate icon assets baked into the Xcode project).
- Release builds are signed with the debug key so `flutter build apk` works out of
  the box — swap in a real keystore before distributing.
