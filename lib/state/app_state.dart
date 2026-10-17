import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/theme/app_tokens.dart';
import '../core/theme/palettes.dart';
import '../data/cache/cache_store.dart';
import '../data/models/server_config.dart';
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
