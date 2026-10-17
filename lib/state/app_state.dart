import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme/app_tokens.dart';
import '../core/theme/palettes.dart';
import '../data/cache/cache_store.dart';
import '../data/models/server_config.dart';
import '../data/models/share_code.dart';
import '../services/settings_store.dart';
import '../services/sound_library.dart';

/// Single source of truth for persisted preferences and the instance list.
class AppState extends ChangeNotifier {
  AppState(this._store) {
    _load();
  }

  final SettingsStore _store;

  SettingsStore get store => _store;

  ThemeModeChoice _themeMode = ThemeModeChoice.system;
  AccentPalette _accent = AccentPalette.all.first;
  UiStyle _uiStyle = UiStyle.kuma;
  Locale? _localeOverride;
  String? _bgImagePath;
  double _bgOpacity = 0.85;
  double _bgBlur = 6;
  bool _notificationsEnabled = true;
  bool _notifyOnDown = true;
  bool _notifyOnUp = true;
  bool _backgroundChecks = true;
  String _soundId = 'chime';
  String _customSoundUri = '';
  String _customSoundPath = '';
  int _pollSeconds = 60;
  List<ServerConfig> _servers = const [];
  String? _activeServerId;
  String _iconVariant = 'default';
  String? _customIconPath;
  bool _uxReport = false;
  bool _dohEnabled = false;
  String _dohUrl = '';
  String _userAgent = '';
  bool _nameClamp = true;
  bool _showSla = false;
  bool _flatGradients = false;
  Color? _statusUpColor;
  Color? _statusDownColor;
  double _uiOpacity = 1.0;
  bool _glass = false;
  bool _headerCompact = false;
  bool _headerGlass = false;
  int _nameClampChars = 18;

  // Read accessors ---------------------------------------------------------
  ThemeModeChoice get themeMode => _themeMode;
  AccentPalette get accent => _accent;
  UiStyle get uiStyle => _uiStyle;
  Locale? get localeOverride => _localeOverride;
  String? get bgImagePath => _bgImagePath;
  double get bgOpacity => _bgOpacity;
  double get bgBlur => _bgBlur;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get notifyOnDown => _notifyOnDown;
  bool get notifyOnUp => _notifyOnUp;
  bool get backgroundChecks => _backgroundChecks;
  SoundOption get sound => SoundOption.byId(
        _soundId,
        customUri: _customSoundUri,
        customLocalPath: _customSoundPath,
      );
  String get customSoundUri => _customSoundUri;
  String get customSoundPath => _customSoundPath;
  String? get customIconPath => _customIconPath;
  bool get uxReport => _uxReport;
  bool get dohEnabled => _dohEnabled;
  /// Custom DoH endpoint (URL + optional port); empty means the built-in list.
  String get dohUrl => _dohUrl;
  String get userAgent => _userAgent;
  bool get nameClamp => _nameClamp;
  bool get showSla => _showSla;
  bool get flatGradients => _flatGradients;

  /// Optional overrides for the "up" / "down" colours; null means theme default.
  Color? get statusUpColor => _statusUpColor;
  Color? get statusDownColor => _statusDownColor;

  /// Card surface opacity multiplier (UI only).
  double get uiOpacity => _uiOpacity;

  /// Frosted-glass cards.
  bool get glass => _glass;

  /// Compact dashboard header (no stat pills).
  bool get headerCompact => _headerCompact;

  /// Frosted glass for the dashboard header only.
  bool get headerGlass => _headerGlass;
  int get nameClampChars => _nameClampChars;
  int get pollSeconds => _pollSeconds;
  List<ServerConfig> get servers => List.unmodifiable(_servers);
  String? get activeServerId => _activeServerId;
  String get iconVariant => _iconVariant;

  ServerConfig? get activeServer {
    if (_servers.isEmpty) return null;
    final id = _activeServerId;
    if (id == null) return _servers.first;
    for (final s in _servers) {
      if (s.id == id) return s;
    }
    return _servers.first;
  }

  ThemeMode get resolvedThemeMode => switch (_themeMode) {
        ThemeModeChoice.light => ThemeMode.light,
        ThemeModeChoice.dark => ThemeMode.dark,
        ThemeModeChoice.system => ThemeMode.system,
      };

  /// Collapses very long monitor names so a row never reflows while the list
  /// is moving. The full name stays available via a tooltip.
  String clampName(String name) {
    if (!_nameClamp) return name;
    final runes = name.runes.toList();
    if (runes.length <= _nameClampChars) return name;
    return '${String.fromCharCodes(runes.take(_nameClampChars))}…';
  }

  bool get hasBackground => _bgImagePath != null && File(_bgImagePath!).existsSync();

  void _load() {
    _themeMode = ThemeModeChoice.values.firstWhere(
      (m) => m.name == _store.themeMode,
      orElse: () => ThemeModeChoice.system,
    );
    _accent = AccentPalette.byId(_store.accentId);
    _uiStyle = _store.uiStyle;
    _localeOverride = _store.localeCode == null ? null : Locale(_store.localeCode!);
    _bgImagePath = _store.bgImagePath;
    if (_bgImagePath != null && !File(_bgImagePath!).existsSync()) _bgImagePath = null;
    _bgOpacity = _store.bgOpacity;
    _bgBlur = _store.bgBlur;
    _notificationsEnabled = _store.notificationsEnabled;
    _notifyOnDown = _store.notifyOnDown;
    _notifyOnUp = _store.notifyOnUp;
    _backgroundChecks = _store.backgroundChecks;
    _soundId = _store.soundId;
    _pollSeconds = _store.pollSeconds;
    _iconVariant = _store.iconVariant;
    _customIconPath = _store.customIconPath;
    _customSoundUri = _store.customSoundUriValue ?? '';
    _customSoundPath = _store.customSoundPath ?? '';
    _uxReport = _store.uxReport;
    _dohEnabled = _store.dohEnabled;
    _dohUrl = _store.dohEndpoint ?? '';
    _userAgent = _store.userAgent ?? '';
    _nameClamp = _store.nameClamp;
    _showSla = _store.showSla;
    _flatGradients = _store.flatGradients;
    final up = _store.statusUpColor;
    final down = _store.statusDownColor;
    _statusUpColor = up == null ? null : Color(up);
    _statusDownColor = down == null ? null : Color(down);
    _uiOpacity = _store.uiOpacity;
    _glass = _store.glass;
    _headerCompact = _store.headerCompact;
    _headerGlass = _store.headerGlass;
    _nameClampChars = _store.nameClampChars;

    final list = ServerConfig.decodeList(_store.serversJson);
    _servers = list;
    _activeServerId = _store.activeServerId ?? (list.isEmpty ? null : list.first.id);
    if (_activeServerId != null && !_servers.any((s) => s.id == _activeServerId)) {
      _activeServerId = _servers.isEmpty ? null : _servers.first.id;
    }
  }

  // Mutations --------------------------------------------------------------
  void setThemeMode(ThemeModeChoice mode) {
    _themeMode = mode;
    _store.themeMode = mode.name;
    notifyListeners();
  }

  void setAccent(AccentPalette palette) {
    _accent = palette;
    _store.accentId = palette.id;
    notifyListeners();
  }

  void setUiStyle(UiStyle style) {
    _uiStyle = style;
    _store.uiStyle = style;
    notifyListeners();
  }

  void setLocale(Locale? locale) {
    _localeOverride = locale;
    _store.localeCode = locale?.languageCode;
    notifyListeners();
  }

  void setBgImage(String? path) {
    _bgImagePath = path;
    _store.bgImagePath = path;
    notifyListeners();
  }

  void setBgOpacity(double v) {
    _bgOpacity = v;
    _store.bgOpacity = v;
    notifyListeners();
  }

  void setBgBlur(double v) {
    _bgBlur = v;
    _store.bgBlur = v;
    notifyListeners();
  }

  void setNotificationsEnabled(bool v) {
    _notificationsEnabled = v;
    _store.notificationsEnabled = v;
    notifyListeners();
  }

  void setNotifyDown(bool v) {
    _notifyOnDown = v;
    _store.notifyOnDown = v;
    notifyListeners();
  }

  void setNotifyUp(bool v) {
    _notifyOnUp = v;
    _store.notifyOnUp = v;
    notifyListeners();
  }

  void setBackgroundChecks(bool v) {
    _backgroundChecks = v;
    _store.backgroundChecks = v;
    notifyListeners();
  }

  void setSound(String id) {
    _soundId = id;
    _store.soundId = id;
    notifyListeners();
  }

  void setPollSeconds(int v) {
    _pollSeconds = v;
    _store.pollSeconds = v;
    notifyListeners();
  }

  void setCustomIconPath(String? path) {
    _customIconPath = path;
    _store.customIconPath = path;
    notifyListeners();
  }

  void setCustomSound({required String uri, required String path}) {
    _customSoundUri = uri;
    _customSoundPath = path;
    _store.customSoundUriValue = uri.isEmpty ? null : uri;
    _store.customSoundPath = path.isEmpty ? null : path;
    notifyListeners();
  }

  void setUxReport(bool v) {
    _uxReport = v;
    _store.uxReport = v;
    notifyListeners();
  }

  void setDohEnabled(bool v) {
    _dohEnabled = v;
    _store.dohEnabled = v;
    notifyListeners();
  }

  void setDohUrl(String v) {
    _dohUrl = v.trim();
    _store.dohEndpoint = _dohUrl;
    notifyListeners();
  }

  void setUserAgent(String v) {
    _userAgent = v;
    _store.userAgent = v;
    notifyListeners();
  }

  void setStatusUpColor(Color? c) {
    _statusUpColor = c;
    _store.statusUpColor = c?.toARGB32();
    notifyListeners();
  }

  void setStatusDownColor(Color? c) {
    _statusDownColor = c;
    _store.statusDownColor = c?.toARGB32();
    notifyListeners();
  }

  void setUiOpacity(double v) {
    _uiOpacity = v.clamp(0.4, 1.0);
    _store.uiOpacity = _uiOpacity;
    notifyListeners();
  }

  void setHeaderCompact(bool v) {
    _headerCompact = v;
    _store.headerCompact = v;
    notifyListeners();
  }

  void setHeaderGlass(bool v) {
    _headerGlass = v;
    _store.headerGlass = v;
    notifyListeners();
  }

  void setGlass(bool v) {
    _glass = v;
    _store.glass = v;
    notifyListeners();
  }

  void setFlatGradients(bool v) {
    _flatGradients = v;
    _store.flatGradients = v;
    notifyListeners();
  }

  void setShowSla(bool v) {
    _showSla = v;
    _store.showSla = v;
    notifyListeners();
  }

  void setNameClamp(bool v) {
    _nameClamp = v;
    _store.nameClamp = v;
    notifyListeners();
  }

  void setNameClampChars(int v) {
    _nameClampChars = v;
    _store.nameClampChars = v;
    notifyListeners();
  }

  void setIconVariant(String id) {
    _iconVariant = id;
    _store.iconVariant = id;
    notifyListeners();
  }

  void _persistServers() {
    _store.serversJson = ServerConfig.encodeList(_servers);
  }

  Future<void> addServer(ServerConfig server) async {
    _servers = [..._servers, server];
    _activeServerId ??= server.id;
    _persistServers();
    _store.activeServerId = _activeServerId;
    notifyListeners();
  }

  Future<void> updateServer(ServerConfig server) async {
    _servers = _servers.map((s) => s.id == server.id ? server : s).toList();
    _persistServers();
    notifyListeners();
  }

  Future<void> removeServer(String id) async {
    _servers = _servers.where((s) => s.id != id).toList();
    if (_activeServerId == id) {
      _activeServerId = _servers.isEmpty ? null : _servers.first.id;
      _store.activeServerId = _activeServerId;
    }
    _persistServers();
    await CacheStore.instance.clearServer(id);
    notifyListeners();
  }

  Future<void> setActiveServer(String id) async {
    _activeServerId = id;
    _store.activeServerId = id;
    notifyListeners();
  }

  // Collections ------------------------------------------------------------
  //
  // A collection is app-local only: instances that share a collectionId are
  // merged into one status page on the phone, in list order. Nothing is sent to
  // the servers, so the published web page is untouched.

  /// Members of [collectionId], in the order they appear in the instance list.
  List<ServerConfig> serversInCollection(String? collectionId) {
    if (collectionId == null) return const [];
    return _servers.where((s) => s.collectionId == collectionId).toList(growable: false);
  }

  /// Every distinct collection, ordered by the position of its first member.
  List<({String id, String name, List<ServerConfig> servers})> get collections {
    final order = <String>[];
    final byId = <String, List<ServerConfig>>{};
    for (final server in _servers) {
      final id = server.collectionId;
      if (id == null || id.isEmpty) continue;
      if (!byId.containsKey(id)) {
        byId[id] = [];
        order.add(id);
      }
      byId[id]!.add(server);
    }
    return [
      for (final id in order)
        (
          id: id,
          name: byId[id]!.first.collectionName ?? 'Collection',
          servers: byId[id]!,
        ),
    ];
  }

  /// Joins [serverId] to a collection, creating one when [collectionName] is a
  /// name that does not exist yet.
  Future<void> joinCollection(String serverId, String collectionName) async {
    final name = collectionName.trim();
    if (name.isEmpty) return;
    final existing = collections.where((c) => c.name == name).toList();
    final id = existing.isEmpty
        ? 'col_${DateTime.now().millisecondsSinceEpoch}'
        : existing.first.id;
    _servers = _servers
        .map((s) => s.id == serverId
            ? s.copyWith(collectionId: id, collectionName: name)
            : s)
        .toList();
    _persistServers();
    notifyListeners();
  }

  /// Puts [serverIds] into one collection in a single step (used when merging
  /// from the instance list).
  Future<void> mergeIntoCollection(
    List<String> serverIds,
    String collectionName,
  ) async {
    final name = collectionName.trim();
    if (name.isEmpty || serverIds.isEmpty) return;
    final existing = collections.where((c) => c.name == name).toList();
    final id = existing.isEmpty
        ? 'col_${DateTime.now().millisecondsSinceEpoch}'
        : existing.first.id;
    _servers = _servers
        .map((s) => serverIds.contains(s.id)
            ? s.copyWith(collectionId: id, collectionName: name)
            : s)
        .toList();
    _persistServers();
    notifyListeners();
  }

  Future<void> leaveCollection(String serverId) async {
    _servers = _servers
        .map((s) => s.id == serverId ? s.copyWith(clearCollection: true) : s)
        .toList();
    _persistServers();
    notifyListeners();
  }

  /// Imports decoded share strings. Returns how many instances were added.
  Future<int> importPayloads(List<SharePayload> payloads) async {
    var added = 0;
    for (final payload in payloads) {
      final collectionId = payload.isCollection
          ? 'col_${DateTime.now().millisecondsSinceEpoch}_$added'
          : null;
      for (final server in payload.servers) {
        final withCollection = payload.isCollection
            ? server.copyWith(
                collectionId: collectionId,
                collectionName: payload.collectionName,
              )
            : server;
        _servers = [..._servers, withCollection];
        added++;
      }
    }
    if (added == 0) return 0;
    _activeServerId ??= _servers.first.id;
    _persistServers();
    _store.activeServerId = _activeServerId;
    notifyListeners();
    return added;
  }

  /// Copies a user-picked image into app storage so it survives cache wipes
  /// and content-uri expiry.
  Future<String> persistBackground(String sourcePath) async {
    final dir = await getApplicationSupportDirectory();
    final target = Directory('${dir.path}/backgrounds');
    if (!await target.exists()) await target.create(recursive: true);
    final ext = sourcePath.split('.').last;
    final file = File('${target.path}/bg_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await File(sourcePath).copy(file.path);
    final old = _bgImagePath;
    if (old != null && old != file.path) {
      try {
        final oldFile = File(old);
        if (await oldFile.exists()) await oldFile.delete();
      } catch (_) {}
    }
    return file.path;
  }
}
