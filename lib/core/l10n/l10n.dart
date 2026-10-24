import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Lightweight, dependency-free localisation.
///
/// Deliberately hand written instead of generated ARB files: the string set is
/// stable, it removes a codegen step from the build, and every key is
/// compile-time checked.
class L10n {
  const L10n(this.locale);

  final Locale locale;

  bool get zh => locale.languageCode == 'zh';

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n) ?? const L10n(Locale('en'));
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// Our delegate plus the Material/Cupertino ones. Chinese date pickers and
  /// widget labels need the latter, so they are always wired together.
  static List<LocalizationsDelegate<dynamic>> delegates() => const [
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static const List<Locale> supported = [Locale('zh'), Locale('en')];

  String _t(String en, String cn) => zh ? cn : en;

  // Shell / navigation ------------------------------------------------------
  String get appTitle => _t('Uptime Kuma', 'Uptime Kuma');
  String get navStatus => _t('Status', '状态');
  String get navServers => _t('Instances', '实例');
  String get navSettings => _t('Settings', '设置');

  // Generic -----------------------------------------------------------------
  String get retry => _t('Retry', '重试');
  String get cancel => _t('Cancel', '取消');
  String get save => _t('Save', '保存');
  String get delete => _t('Delete', '删除');
  String get edit => _t('Edit', '编辑');
  String get add => _t('Add', '添加');
  String get importInstance => _t('Import instance', '导入实例');
  String get importCollection => _t('Import collection', '导入实例集合');
  String get importInstanceHint => _t('Paste an uptimekuma:// link', '粘贴 uptimekuma:// 链接');
  String get importCollectionHint =>
      _t('Paste a collection link to add several at once', '粘贴集合链接，一次导入多个实例');
  String get importHint => _t(
        'Paste one or more uptimekuma:// links, one per line. Credentials are '
            'never included, so management instances ask for a password again.',
        '粘贴一条或多条 uptimekuma:// 链接，每行一条。导出不含任何凭据，管理模式实例导入后需重新登录。',
      );
  String get importAction => _t('Import', '导入');
  String get pasteFromClipboard => _t('Paste', '粘贴');
  String get importInvalid => _t('Nothing importable in that text', '这段内容里没有可导入的配置');
  String importedCount(int n) => _t('Imported $n instance(s)', '已导入 $n 个实例');
  String get exportConfig => _t('Export config', '导出配置');
  String get exportCollection => _t('Export collection', '导出集合');
  String get exportedToClipboard => _t('Copied to clipboard', '已复制到剪贴板');
  String get joinCollection => _t('Join a collection', '加入集合');
  String get leaveCollection => _t('Leave collection', '移出集合');
  String get collection => _t('Collection', '集合');
  String get collectionName => _t('Collection name', '集合名称');
  String get collectionHint => _t(
        'Instances in the same collection share one status page on the phone, '
            'in list order. Nothing changes on the server.',
        '同一集合的实例会在手机上合并成一个状态页，按列表顺序排列。不会影响服务器端。',
      );
  String collectionMembers(int n) => _t('$n instances · merged', '$n 个实例 · 已合并');
  String mergedInstances(int n) => _t('$n instances merged', '$n 个实例已合并');
  String get done => _t('Done', '完成');
  String get close => _t('Close', '关闭');
  String get refresh => _t('Refresh', '刷新');
  String get confirm => _t('Confirm', '确认');
  String get unknown => _t('Unknown', '未知');
  String get never => _t('Never', '从未');
  String get justNow => _t('Just now', '刚刚');
  String get loading => _t('Loading', '加载中');
  String get optional => _t('Optional', '可选');
  String get copy => _t('Copy', '复制');
  String get copied => _t('Copied', '已复制');

  // Status words ------------------------------------------------------------
  String get statusUp => _t('Operational', '运行正常');
  String get statusDown => _t('Down', '故障');
  String get statusPending => _t('Pending', '等待中');
  String get statusMaintenance => _t('Maintenance', '维护中');
  String get statusPaused => _t('Paused', '已暂停');
  String get statusUnknown => _t('Unknown', '未知');

  String get overallOperational => _t('All systems operational', '所有系统运行正常');
  String get overallPartial => _t('Partial outage', '部分服务异常');
  String get overallMajor => _t('Major outage', '大面积故障');
  String get overallUnknown => _t('Status unavailable', '状态不可用');

  // Time --------------------------------------------------------------------
  String secondsAgo(int n) => _t('$n s ago', '$n 秒前');
  String minutesAgo(int n) => _t('$n min ago', '$n 分钟前');
  String hoursAgo(int n) => _t('$n h ago', '$n 小时前');
  String daysAgo(int n) => _t('$n d ago', '$n 天前');
  String get lastUpdated => _t('Last updated', '最后更新');
  String get updated => _t('Updated', '已更新');

  // Dashboard ---------------------------------------------------------------
  String get summary => _t('Summary', '总览');
  String monitorsCount(int n) => _t('$n monitors', '$n 个监控项');
  String get upCount => _t('Up', '正常');
  String get downCount => _t('Down', '故障');
  String get pendingCount => _t('Pending', '等待');
  String get maintenanceCount => _t('Maint.', '维护');
  String get uptime24h => _t('24h', '24 小时');
  String get uptime7d => _t('7d', '7 天');
  String get uptime30d => _t('30d', '30 天');
  String get uptime90d => _t('90d', '90 天');
  String get uptime => _t('Uptime', '可用率');
  String get responseTime => _t('Response', '响应');
  String get responseTimeMs => _t('Response time', '响应时间');
  String get noData => _t('No data', '暂无数据');
  String get noMonitors => _t('No monitors published yet', '暂无公开监控项');
  String get heartbeatHistory => _t('Heartbeat history', '心跳记录');
  String get last60Checks => _t('Last 60 checks', '最近 60 次检查');
  String lastChecks(int n) => _t('Last $n checks', '最近 $n 次检查');
  String get certExpiry => _t('Certificate', '证书');
  String certDaysLeft(int d) => _t('$d days left', '剩余 $d 天');
  String get certExpired => _t('Expired', '已过期');
  String get certValid => _t('Valid', '有效');
  String get certTls => _t('TLS certificate', 'TLS 证书');
  String get incidents => _t('Incidents', '故障事件');
  String get maintenance => _t('Maintenance', '维护计划');
  String get activeIncident => _t('Active incident', '进行中的故障');
  String get scheduledMaintenance => _t('Scheduled maintenance', '计划维护');
  String get offlineBanner => _t('Showing cached data — instance unreachable', '显示缓存数据 — 实例无法访问');
  String get pullToRefresh => _t('Pull down to refresh', '下拉刷新');
  String get searchMonitors => _t('Search monitors', '搜索监控项');

  // Monitor detail ----------------------------------------------------------
  String get monitorDetail => _t('Monitor', '监控详情');
  String get details => _t('Details', '详细信息');
  String get type => _t('Type', '类型');
  String get uptimeStats => _t('Uptime', '可用率统计');
  String get avgResponse => _t('Average', '平均值');
  String get minResponse => _t('Min', '最小');
  String get maxResponse => _t('Max', '最大');
  String get recentEvents => _t('Recent events', '最近事件');
  String get noEvents => _t('No recorded events', '暂无事件记录');
  String get notPublicUrl => _t('Link not published', '未公开链接');
  String get openStatusPage => _t('Open status page', '打开状态页');
  String get monitoredSince => _t('Monitoring since', '开始监控');
  String get checkEvery => _t('Checked', '检查间隔');

  // Servers -----------------------------------------------------------------
  String get myInstances => _t('Instances', '实例');
  String get instanceList => _t('Uptime Kuma instances', 'Uptime Kuma 实例');
  String get addInstance => _t('Add instance', '添加实例');
  String get editInstance => _t('Edit instance', '编辑实例');
  String get instanceName => _t('Display name', '显示名称');
  String get instanceNameHint => _t('e.g. Production', '例如：生产环境');
  String get baseUrl => _t('Server URL', '服务器地址');
  String get baseUrlHint => _t('https://status.example.com', 'https://status.example.com');
  String get slug => _t('Status page slug', '状态页 Slug');
  String get slugHint => _t('e.g. main', '例如：main');
  String get slugHelp => _t(
        'The part after /status/ on your public page. Paste the whole status page link and it will be extracted automatically.',
        '公开状态页 /status/ 之后的路径。也可以直接粘贴完整的状态页链接，会自动识别。',
      );
  String get testConnection => _t('Test connection', '测试连接');
  String get testing => _t('Testing…', '测试中…');
  String get connectionFailed => _t('Connection failed', '连接失败');

  String get connectionOk => _t('Connected', '连接成功');
  String get setActive => _t('Use this instance', '切换到此实例');
  String get active => _t('Active', '当前');
  String get deleteInstance => _t('Delete instance', '删除实例');
  String deleteInstanceBody(String name) =>
      _t('Remove “$name” and its cached data?', '确定删除“$name”及其缓存数据？');
  String get noInstances => _t('No instances yet', '还没有实例');
  String get noInstancesHint => _t('Add your Uptime Kuma server to get started.', '添加你的 Uptime Kuma 服务器开始使用。');
  String get requiredField => _t('Required', '必填');
  String get createStatusPage => _t('Create a status page', '新建状态页');
  String get statusPageTitleField => _t('Title', '标题');
  String get statusPageSlugField => _t('Slug', '路径');
  String get statusPageSlugHint => _t('lowercase letters, digits, dashes', '小写字母、数字、连字符');
  String get create => _t('Create', '创建');
  String get statusPageCreated => _t('Status page created', '状态页已创建');
  String get invalidUrl => _t('Enter a valid http(s) URL', '请输入有效的 http(s) 地址');
  String get detected => _t('Detected', '已识别');

  // Settings ----------------------------------------------------------------
  String get settingsAppearance => _t('Appearance', '外观');
  String get settingsNotifications => _t('Notifications', '通知');
  String get notifications => _t('Notifications', '通知');
  String get settingsData => _t('Data & cache', '数据与缓存');
  String get settingsGeneral => _t('General', '通用');
  String get themeMode => _t('Theme', '主题');
  String get themeLight => _t('Light', '明亮');
  String get themeDark => _t('Dark', '暗黑');
  String get themeSystem => _t('Follow system', '跟随系统');
  String get accentColor => _t('Accent colour', '主题色');
  String get uiStyle => _t('Interface style', '界面风格');
  String get uiStyleKuma => _t('Uptime Kuma', 'Uptime Kuma 圆角');
  String get uiStyleKumaHint => _t('Rounded cards, pill badges, airy spacing', '大圆角卡片、胶囊标签、宽松留白');
  String get uiStyleTencent => _t('Tencent Cloud', '腾讯云直角');
  String get uiStyleTencentHint => _t('Square corners, hairline borders, dense rows', '直角、细边框、紧凑行距');
  String get language => _t('Language', '语言');
  String get languageZh => _t('简体中文', '简体中文');
  String get languageEn => _t('English', 'English');
  String get backgroundImage => _t('Background image', '背景图');
  String get backgroundImageHint => _t('Applied behind every page', '应用于所有页面背景');
  String get pickImage => _t('Choose image', '选择图片');
  String get removeImage => _t('Remove', '移除');
  String get bgOpacity => _t('Image opacity', '图片不透明度');
  String get bgBlur => _t('Image blur', '图片模糊');
  String get imagePickerUnavailable => _t('Image picker unavailable', '无法打开图片选择器');

  String get enableNotifications => _t('Enable alerts', '启用告警通知');
  String get enableNotificationsHint =>
      _t('Send a notification when a monitor changes state', '监控项状态变化时发送系统通知');
  String get notifyOnDown => _t('Notify on outage', '故障时通知');
  String get notifyOnUp => _t('Notify on recovery', '恢复时通知');
  String get notifySound => _t('Alert sound', '提醒音效');
  String get preview => _t('Preview', '试听');
  String get persistentTitle => _t('UptimeKumaAPP is monitoring', 'UptimeKumaAPP 正在监控');
  String get persistentBody => _t(
        'Alerts stay armed while the app is running. Pull down to refresh.',
        '应用运行期间告警保持开启，下拉可刷新。',
      );
  String get persistentSwitch => _t('Pin a status notification', '通知栏常驻');
  String get persistentSwitchBody => _t(
        'Keeps a silent, non-dismissible entry in the notification shade so you '
            'can tell the monitor is alive. It disappears with the app process.',
        '在通知栏保留一条静默且无法滑动清除的条目，用来确认监控仍在运行。'
            '进程结束后它会随之消失。',
      );
  String get foregroundServiceTitle => _t('Foreground service', '前台服务');
  String get foregroundServiceBody => _t(
        'Runs the pinned entry from a foreground service: it can no longer be '
            'swiped away, and Android is far less likely to kill the polling '
            'process. Uses the specialUse type, so it is not capped like '
            'dataSync.',
        '由前台服务承载常驻通知：无法滑动清除，系统也更不容易杀掉轮询进程。'
            '使用 specialUse 类型，不受 dataSync 的每日时长限制。',
      );
  String get aboutFeedback => _t('Report an issue', '问题反馈');
  String get openFailed => _t('Could not open the browser', '无法打开浏览器');
  String get openSourceTitle => _t('Open-source licence', '开源许可');
  String get openSourceBody => _t(
        'This app is distributed under the GNU General Public License v3.0.',
        '本应用以 GNU 通用公共许可证第三版（GPL-3.0）发布。',
      );
  String get viewLicense => _t('View the licence', '查看许可全文');
  String get gplTitle => _t('GNU GPL v3.0', 'GNU GPL v3.0');
  String get bgIntervalTitle => _t('Check interval', '检查间隔');
  String bgMinutes(int m) => _t('$m min', '$m 分钟');
  String get bgIntervalBody => _t(
        'WorkManager will not go below 15 minutes on its own, so shorter '
            'intervals run as a chain of one-shot tasks. Android may still batch '
            'them while the phone is dozing.',
        '系统周期任务最低 15 分钟，更短的间隔由一串一次性任务接力实现；'
            '手机进入深度睡眠时系统仍可能推迟执行。',
      );
  String get inAppSoundTitle => _t('Play the tone inside the app', '应用内播放提示音');
  String get inAppSoundBody => _t(
        'Android 16 devices sometimes never start the notification channel '
            'sound. With this on, the app plays the same tone itself while it is '
            'open. Turn it off if you hear the alert twice.',
        '部分 Android 16 设备不会播放通知渠道声音。开启后，应用在前台时会自己再播一遍。'
            '如果听到重复提示音，可以关掉。',
      );
  String get previewFailed => _t('Preview failed', '试听失败');
  String get previewFileMissing => _t(
        'The uploaded file is gone. Pick it again.',
        '上传的音频文件已不存在，请重新选择。',
      );
  String get diagnosticsTitle => _t('Notification diagnostics', '通知诊断');
  String get diagnosticsRun => _t('Run', '运行');
  String get diagnosticsHint => _t(
        'Shows what Android reports about permissions and channels — copy it '
            'when reporting a missing sound.',
        '显示系统报告的通知权限与渠道状态，反馈无声问题时请复制这段内容。',
      );
  String get copyDiagnostics => _t('Copy', '复制');
  String get channelSilentTitle => _t('This alert channel is muted', '该告警渠道已被静音');
  String get channelSilentBody => _t(
        'Android reports no sound for the channel used by the selected tone — '
            'usually because the system rewrote it during an upgrade. Open the '
            'app\'s notification settings and switch “Uptime Kuma monitor state '
            'changes” back on, or pick another tone to create a fresh channel.',
        '系统报告该音效对应的通知渠道没有声音——通常是升级后被系统改写。请到应用通知设置里把'
            '“Uptime Kuma monitor state changes”重新允许声音，或换一个音效以创建新渠道。',
      );
  String get openSystemNotificationSettings =>
      _t('Open settings', '打开设置');
  String get notificationPermission => _t('Notification permission', '通知权限');
  String get permissionGranted => _t('Granted', '已授权');
  String get permissionDenied => _t('Denied', '未授权');
  String get grantPermission => _t('Request permission', '请求权限');
  String get testNotification => _t('Send test notification', '发送测试通知');
  String get pollInterval => _t('Refresh interval', '刷新间隔');
  String pollIntervalValue(int s) => _t('every $s s', '每 $s 秒');
  String get backgroundCheck => _t('Background checks', '后台检查');
  String get backgroundCheckHint => _t(
        'Android runs a periodic task (min. 15 min) so alerts arrive with the app closed.',
        'Android 会运行周期任务（最短 15 分钟），即使应用关闭也能收到告警。',
      );
  String get backgroundUnsupported => _t('Only supported on Android', '仅 Android 支持');
  String get alertDetail => _t('Include error detail and start time', '包含故障信息与开始时间');

  String get cacheSize => _t('Cache size', '缓存占用');
  String get cacheSnapshots => _t('Status snapshots', '状态快照');
  String get cacheSnapshotsBody => _t(
        'The last response of every instance, so the dashboard opens with data '
            'instead of a spinner. Clearing it only costs one refresh.',
        '每个实例最近一次的状态数据，用于冷启动时直接出内容。清理后只会重新拉取一次。',
      );
  String get cacheImages => _t('Downloaded logos', '状态页图标');
  String get cacheImagesBody => _t(
        'Icons published by each status page. They are kept on disk so switching '
            'instances shows the logo immediately instead of waiting for the network.',
        '各状态页发布的图标，保存在本地磁盘上，切换实例时立即显示而不是等网络。',
      );
  String get clear => _t('Clear', '清理');
  String filesCount(int n) => _t('$n files', '$n 个文件');
  String get clearCache => _t('Clear cache', '清理缓存');
  String get clearCacheConfirm => _t(
        'Cached status pages and heartbeat data will be removed. Settings are kept.',
        '将删除已缓存的状态页与心跳数据，设置会保留。',
      );
  String get cacheCleared => _t('Cache cleared', '缓存已清理');
  String get cacheEmpty => _t('Nothing cached', '暂无缓存');
  String get storageUsed => _t('Local storage', '本地存储');

  String get appIcon => _t('App icon', '应用图标');
  String get appIconHint => _t('Switch the launcher icon at runtime', '运行时切换桌面图标');
  String get iconDefault => _t('Terminal', '终端蓝');
  String get iconEmerald => _t('Emerald', '翡翠');
  String get iconMidnight => _t('Midnight', '午夜');
  String get iconCrimson => _t('Crimson', '朱红');
  String get iconRestartHint =>
      _t('Some launchers apply the new icon after a moment.', '部分桌面需要稍等片刻才会刷新图标。');
  String get iconUnsupported => _t('Custom launcher icons are Android only', '自定义桌面图标仅支持 Android');

  String get about => _t('About', '关于');
  String get version => _t('Version', '版本');

  // Notification bodies -----------------------------------------------------
  String notifDownTitle(String name) => _t('$name is down', '【故障】$name 已宕机');
  String notifUpTitle(String name) => _t('$name recovered', '【恢复】$name 已恢复');
  String notifDownBody({
    required String status,
    required String startTime,
    required String instance,
    String? detail,
    String? downtime,
  }) {
    final b = StringBuffer();
    b.writeln(zh ? '状态：$status' : 'Status: $status');
    b.writeln(zh ? '开始时间：$startTime' : 'Started: $startTime');
    if (downtime != null) {
      b.writeln(zh ? '持续时间：$downtime' : 'Elapsed: $downtime');
    }
    b.writeln(zh ? '实例：$instance' : 'Instance: $instance');
    if (detail != null && detail.trim().isNotEmpty) {
      b.write(zh ? '详情：$detail' : 'Detail: $detail');
    }
    return b.toString().trimRight();
  }

  String notifUpBody({
    required String status,
    required String startTime,
    required String instance,
    String? downtime,
    String? detail,
  }) {
    final b = StringBuffer();
    b.writeln(zh ? '状态：$status' : 'Status: $status');
    if (downtime != null) {
      b.writeln(zh ? '故障持续：$downtime' : 'Outage lasted: $downtime');
    }
    b.writeln(zh ? '恢复时间：$startTime' : 'Recovered: $startTime');
    b.writeln(zh ? '实例：$instance' : 'Instance: $instance');
    if (detail != null && detail.trim().isNotEmpty) {
      b.write(zh ? '详情：$detail' : 'Detail: $detail');
    }
    return b.toString().trimRight();
  }

  String get testNotifTitle => _t('Uptime Kuma alert test', 'Uptime Kuma 告警测试');
  String get testNotifBody => _t(
        'If you can read this, notifications work. Status: down · Started: now · Instance: demo',
        '能看到这条说明通知正常。状态：故障 · 开始时间：刚刚 · 实例：演示',
      );

  // Onboarding -------------------------------------------------------------
  String get guideHeadline => _t('No instance yet', '还没有接入实例');
  String get guideLead => _t(
        'This app is a client for your own Uptime Kuma server. Add one to start.',
        '本应用是你自己 Uptime Kuma 服务的客户端，先接入一个实例即可开始。',
      );
  String get guideStep1Title => _t('Open Uptime Kuma', '打开 Uptime Kuma');
  String get guideStep1Body => _t(
        'Copy your dashboard URL, or the public status page link under Status Pages.',
        '复制面板地址，或「状态页面」里的公开访问链接。',
      );
  String get guideStep2Title => _t('Pick a mode', '选择接入方式');
  String get guideStep2Body => _t(
        'Monitor only needs a status page URL. Management needs an account.',
        '只看监控只需要状态页地址；要管理则需账号。',
      );
  String get guideStep3Title => _t('Read the board', '查看面板');
  String get guideStep3Body => _t(
        'Live status, 60-beat timeline, response chart and outage alerts.',
        '实时状态、60 格心跳、响应时间曲线与故障提醒。',
      );
  String get guideAddNow => _t('Add your first instance', '添加第一个实例');
  String get guideNoPreset => _t(
        'No demo data is bundled — everything you see comes from your own server.',
        '不内置任何演示数据，你看到的一切都来自你自己的服务器。',
      );

  // Instance form ----------------------------------------------------------
  String get modeMonitorTitle => _t('Monitor only', '只挂监控');
  String get modeMonitorBody => _t(
        'Public status page URL. Read-only, no credentials stored.',
        '公开状态页地址，只读，不保存任何凭据。',
      );
  String get modeManageTitle => _t('Manage from phone', '移动端管理');
  String get modeManageBody => _t(
        'Sign in with an Uptime Kuma account to add, edit and delete monitors.',
        '用 Uptime Kuma 账号登录，可增删改监控项、通知与事件。',
      );
  String get fieldStatusUrl => _t('Status page URL', '状态页地址');
  String get fieldServerUrl => _t('Server URL', '服务器地址');
  String get fieldSlug => _t('Status page slug', '状态页标识');
  String get fieldApiKey => _t('API key (optional)', 'API Key（可选）');
  String get fieldUsername => _t('Username', '用户名');
  String get fieldPassword => _t('Password', '密码');
  String get fieldOtp => _t('2FA code', '两步验证码');
  String get apiKeyHint => _t(
        'An API key only unlocks /metrics. Management always goes through an account login.',
        'API Key 只能读取 /metrics；管理功能必须用账号登录。',
      );
  String get passwordHint => _t(
        'Used once to get a session token. The password is never stored.',
        '只用于换取会话令牌，密码不会被保存。',
      );
  String get signInBtn => _t('Sign in', '登录');
  String get signingIn => _t('Signing in…', '登录中…');
  String get slugOptional => _t('Leave empty if the page is not published', '未发布状态页可留空');

  // Management -------------------------------------------------------------
  String get navManage => _t('Manage', '管理');
  String get manageMonitors => _t('Monitors', '监控项');
  String get manageAddMonitor => _t('New monitor', '新建监控项');
  String get manageEditMonitor => _t('Edit monitor', '编辑监控项');
  String get monitorName => _t('Name', '名称');
  String get monitorType => _t('Type', '类型');
  String get monitorTarget => _t('Target', '目标');
  String get monitorUrl => _t('URL', '地址');
  String get monitorHostname => _t('Hostname', '主机名');
  String get monitorPort => _t('Port', '端口');
  String get monitorInterval => _t('Check interval (s)', '检测间隔（秒）');
  String get monitorMaxRetries => _t('Retries', '重试次数');
  String get monitorTimeout => _t('Timeout (s)', '超时（秒）');
  String get monitorCodes => _t('Accepted status codes', '可接受状态码');
  String get monitorKeyword => _t('Keyword', '关键词');
  String get monitorInvert => _t('Keyword must be absent', '要求关键词不存在');
  String get monitorParent => _t('Group', '所属分组');
  String get monitorNotifications => _t('Notifications', '通知');
  String get monitorActive => _t('Enabled', '启用');
  String get monitorUpsideDown => _t('Invert status', '反转状态');
  String get monitorMethod => _t('Method', '请求方法');
  String get monitorDescription => _t('Description', '描述');
  String get noGroup => _t('No group', '不分组');
  String get monitorSaved => _t('Monitor saved', '监控项已保存');
  String get monitorDeleted => _t('Monitor deleted', '监控项已删除');
  String get confirmDeleteMonitor => _t('Delete this monitor and all its history?', '删除该监控项及其全部历史记录？');
  String get pausedLabel => _t('Paused', '已暂停');
  String get pause => _t('Pause', '暂停');
  String get resumeBtn => _t('Resume', '恢复');
  String get noMonitorsYet => _t('No monitors on this instance yet.', '该实例还没有监控项。');
  String get addFirstMonitor => _t('Create the first one', '去创建第一个');
  String get sessionExpired => _t('Session expired, sign in again.', '会话已失效，请重新登录。');
  String get signInAgain => _t('Sign in again', '重新登录');
  String get manageSignInLead => _t(
        'Sign in to manage monitors, notifications and incidents.',
        '登录后可管理监控项、通知与事件。',
      );
  String get notificationsTab => _t('Notifications', '通知');
  String get notificationType => _t('Provider', '通道类型');
  String get notificationName => _t('Display name', '名称');
  String get notificationEnabled => _t('Enabled', '启用');
  String get notificationDefault => _t('Default for new monitors', '新监控默认使用');
  String get addNotification => _t('New notification', '新建通知通道');
  String get notificationSaved => _t('Notification saved', '通知通道已保存');
  String get notificationDeleted => _t('Notification deleted', '通知通道已删除');
  String get sendTest => _t('Send test', '发送测试');
  String get testSent => _t('Test notification sent', '测试通知已发送');
  String get noNotificationsYet => _t('No notification channel yet.', '还没有通知通道。');
  String get eventsTab => _t('Events', '事件');
  String get postEvent => _t('Post incident', '发布事件');
  String get eventTitle => _t('Title', '标题');
  String get eventContent => _t('Content', '内容');
  String get eventStyle => _t('Severity', '级别');
  String get eventPinned => _t('Pin to top', '置顶');
  String get eventAutoPinned => _t(
        'Kuma pins every new incident to the top of the status page.',
        'Kuma 会把新事件自动置顶在状态页。',
      );
  String get eventPosted => _t('Incident posted', '事件已发布');
  String get statusPageLabel => _t('Status page', '状态页');
  String get noStatusPageHint => _t(
        'This instance has no status page yet, so incidents cannot be posted.',
        '该实例还没有状态页，无法发布事件。',
      );
  String get styleInfo => _t('Info', '提示');
  String get styleWarning => _t('Warning', '警告');
  String get styleDanger => _t('Outage', '故障');
  String get stylePrimary => _t('Primary', '主要');
  String get needManageMode => _t(
        'Switch this instance to management mode to edit it.',
        '将该实例切换为管理模式后才能编辑。',
      );

  // Settings ---------------------------------------------------------------
  String get settingsAbout => _t('About', '关于');
  String get settingsPrivacy => _t('Privacy', '隐私');
  String get aboutVersion => _t('Version', '版本号');
  String get aboutContact => _t('Contact', '联系方式');
  String get aboutBusiness => _t('Business', '商务合作');
  String get aboutProject => _t('Project', '项目链接');
  String get aboutHash => _t('Build hash', '构建哈希');
  String get aboutHashHint => _t(
        'SHA-256 of this package signature, so you can verify what you installed.',
        '本安装包签名的 SHA-256 摘要，可用于校验安装来源。',
      );
  String get copyDone => _t('Copied', '已复制');
  String get privacyUxTitle => _t('Usage improvement', '用户体验改进');
  String get privacyUxBody => _t(
        'Sends one anonymous ping per cold start. Nothing else is collected.',
        '每次冷启动发送一次匿名请求，不采集其他任何信息。',
      );
  String get privacyDohTitle => _t('Use DNS over HTTPS', '使用 DoH');
  String get privacyDohBody => _t(
        'Resolves instance hostnames through a DoH JSON API. Defaults to '
            'Cloudflare, then Google; set your own endpoint below.',
        '通过 DoH JSON 接口解析实例域名。默认先 Cloudflare 再 Google，也可在下方填写自建端点。',
      );
  String get assistTitle => _t('Help with debugging', '协助调试');
  String get assistBody => _t(
        'Runs every feature once and reports what it found: permissions, '
            'notification channel, DoH, each instance, caches and current '
            'settings. Copy the result when reporting a problem.',
        '把现有功能逐个跑一遍并报告结果：权限、通知渠道、DoH、每个实例、缓存与当前设置。'
            '反馈问题时复制这份报告即可。',
      );
  String get runAllChecks => _t('Run all checks', '运行全部检查');
  String get copyReport => _t('Copy report', '复制报告');
  String get silentLoginTitle => _t('Silent sign-in', '凭据静默登录');
  String get silentLoginBody => _t(
        'Keeps the management password in the system keystore so an expired '
            'session is renewed without a prompt. Turning this off deletes every '
            'stored password.',
        '将管理密码保存在系统密钥库中，会话过期时自动重新登录、不再弹窗。'
            '关闭此选项会删除全部已保存的密码。',
      );
  String get dohTest => _t('Test', '测试');
  String dohTestOk(String address) => _t('Resolved $address', '解析成功 · $address');
  String dohTestStatus(int code) =>
      _t('Server answered HTTP $code', '服务器返回 HTTP $code');
  String dohTestError(String message) => _t('Request failed: $message', '请求失败：$message');
  String get dohEndpointTitle => _t('DoH endpoint', 'DoH 服务地址');
  String get dohEndpointBody => _t(
        'A DoH server address, port optional. Both the standard RFC 8484 '
            'wire format and the JSON API are supported; a bare domain gets '
            '/dns-query appended automatically. Leave empty for the defaults.',
        'DoH 服务器地址，端口可省略。同时兼容标准 RFC 8484 与 JSON 接口；只填域名会自动补 /dns-query。留空则使用默认服务。',
      );
  String get dohEndpointHint => _t(
        'https://doh.zakoflare.com/dns-query',
        'https://doh.zakoflare.com/dns-query',
      );
  String get privacyUaTitle => _t('Custom User-Agent', '自定义 UA');
  String get privacyUaBody => _t(
        'Overrides the User-Agent sent to your instances.',
        '覆盖请求实例时使用的 User-Agent。',
      );
  String get privacyUaHint => _t('Leave empty to use the default', '留空则使用默认值');
  String get resetDefault => _t('Reset', '重置');
  String get switchInstance => _t('Switch instance', '切换实例');
  String get privacyDataNote => _t(
        'Credentials, caches and settings never leave the device.',
        '凭据、缓存与设置都不会离开本机。',
      );
  String get nameClampTitle => _t('Collapse long monitor names', '折叠过长监控名');
  String get statusColorsTitle => _t('Status colours', '状态色');
  String get statusColorsBody => _t(
        'These two drive the dot, heartbeat strip, latency line and badges on '
            'every monitor row.',
        '这两色会应用到每条监控的状态点、心跳条、延迟线与徽标。',
      );
  String get statusColorUp => _t('Up / healthy', '正常');
  String get statusColorDown => _t('Down / fault', '故障');
  String get statusColorReset => _t('Use the default palette', '使用默认配色');
  String get uiEffectsTitle => _t('UI effects', '界面效果');
  String get previewTitle => _t('Preview', '效果预览');
  String get previewHint => _t(
        'Drag the controls below: cards and the header update against your own '
            'photo. This page is the only place the photo is shown behind the UI.',
        '拖动下方控件即可看到卡片与头部的真实效果。这是唯一会在界面下显示背景图的设置页。',
      );
  String get previewInstance => _t('Sample instance', '示例实例');
  String get previewSubtitle => _t('3 monitors · updated just now', '3 个监控项 · 刚刚更新');
  String get previewMonitorA => _t('Edge node · Tokyo', '边缘节点 · 东京');
  String get previewMonitorB => _t('Origin · Frankfurt', '源站 · 法兰克福');
  String get headerSectionTitle => _t('Dashboard header', '首页头部');
  String get headerFull => _t('Full', '完整版');
  String get headerCompact => _t('Compact', '简略版');
  String get headerLayoutBody => _t(
        'Full keeps the counter pills, compact keeps only the status line.',
        '完整版保留四个计数卡片，简略版只留一行状态。',
      );
  String get headerGlassTitle => _t('Header frosted glass', '头部毛玻璃');
  String get headerGlassBody => _t(
        'Lets the photo show through the header. Follows the interface opacity '
            'slider below; off keeps the header solid.',
        '头部半透明并透出背景图，透明度由下面的"界面不透明度"控制；关闭则保持实心。',
      );
  String get glassTitle => _t('Frosted glass', '毛玻璃');
  String get glassBody => _t(
        'Cards blur what is behind them and turn translucent. Only the interface '
            'is affected — the background photo keeps its own opacity.',
        '卡片对身后的内容做模糊并半透明。只影响界面，背景图仍使用自己的不透明度。',
      );
  String get uiOpacityTitle => _t('Interface opacity', '界面不透明度');
  String get uiOpacityBody => _t(
        'How solid cards, sheets and panels are. Lower values let more of the '
            'background through.',
        '卡片、弹层与面板的实心程度，数值越低背景透出越多。',
      );
  String get flatTitle => _t('Solid colours (no gradients)', '纯色（取消渐变）');
  String get flatBody => _t(
        'Turns the header fade and its glow into one flat accent colour, and '
            'drops the large drop shadow. Switches keep working the same way.',
        '把首页头部的渐变和光晕换成单色，并去掉大阴影，其余交互不变。',
      );
  String get showSlaTitle => _t('Show SLA / uptime %', '显示 SLA / 可用率');
  String get showSlaBody => _t(
        'Shows the 24h uptime percentage on every monitor row and the '
            '24h / 30d / 90d windows on the detail page. Off by default.',
        '在每条监控右侧显示 24h 可用率，并在详情页显示 24h / 30d / 90d 统计。默认关闭。',
      );
  String get nameClampBody => _t(
        'Truncates the tail of long names so the row stops reflowing.',
        '超长名称折叠后段，避免行内重排导致的抖动。',
      );
  String get nameClampChars => _t('Keep first N characters', '保留前 N 个字符');

  // Icons & sounds ---------------------------------------------------------
  String get iconCustomTitle => _t('Custom icon', '自定义图标');
  String get iconPickFile => _t('Choose image', '选择图片');
  String get iconFromUrl => _t('From URL', '从链接导入');
  String get iconUrlHint => _t('https://example.com/icon.png', 'https://example.com/icon.png');
  String get iconApply => _t('Apply', '应用');
  String get iconCustomActive => _t('Custom icon in use', '当前使用自定义图标');
  String get iconTaskApplied => _t(
        'Applied to the recents card. The home-screen icon can only be '
            'replaced through a pinned shortcut, which this launcher does not offer.',
        '已应用到最近任务卡片。桌面图标只能通过「固定快捷方式」替换，当前桌面不支持。',
      );
  String get iconPinHint => _t(
        'Android cannot swap the launcher bitmap at runtime, so the custom image is pinned to the home screen as its own shortcut.',
        'Android 无法在运行时替换桌面图标位图，因此自定义图片会以独立快捷方式固定到桌面。',
      );
  String get iconApplying => _t('Applying…', '应用中…');
  String get iconDownloadFailed => _t('Could not download that image', '该图片无法下载');
  String get iconPresetOnly => _t(
        'Preset icons only: Android does not allow an app to swap its launcher '
            'icon for a custom image at runtime.',
        '仅提供预设图标：Android 不允许应用在运行时把桌面图标换成自定义图片。',
      );
  String get iconPinStarted => _t('Confirm the shortcut on your launcher', '请在桌面确认添加');
  String get soundUpload => _t('Upload tone', '上传提示音');
  String get soundUploadHint => _t('mp3 / wav', 'mp3 / wav');
  String get soundInstalled => _t('Tone installed', '提示音已安装');
  String get soundInstallFailed => _t('Could not install that file', '该文件无法使用');
  String get soundPreviewOnly => _t(
        'Saved. Android denied access to the notification sound folder, '
            'so alerts keep the built-in tone while this file still previews here.',
        '已保存。系统未授权写入通知音频目录，通知将回退到内置提示音，此文件仍可在此试听。',
      );
  String get chartTapHint => _t('Tap the chart to read a sample', '点击曲线可查看采样点');
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}
