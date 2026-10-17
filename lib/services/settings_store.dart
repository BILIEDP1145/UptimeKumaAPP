import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_tokens.dart';

/// Central key registry so the background isolate and the UI agree on storage.
class PrefKeys {
  static const themeMode = 'theme_mode';
  static const accentId = 'accent_id';
  static const uiStyle = 'ui_style';
  static const locale = 'locale_code';
  static const bgImage = 'bg_image_path';
  static const bgOpacity = 'bg_opacity';
  static const bgBlur = 'bg_blur';
  static const notifications = 'notif_enabled';
  static const notifyDown = 'notif_down';
  static const notifyUp = 'notif_up';
  static const soundId = 'notif_sound';
  static const pollSeconds = 'poll_seconds';
  static const backgroundChecks = 'bg_checks';
  static const servers = 'servers_json';
  static const activeServer = 'active_server_id';
  static const iconVariant = 'icon_variant';
  static const customIcon = 'custom_icon_path';
  static const customSound = 'custom_sound_path';
  static const customSoundUri = 'custom_sound_uri';
  static const uxReport = 'ux_report';
  static const doh = 'doh_enabled';
  static const dohUrl = 'doh_endpoint';
  static const userAgent = 'custom_user_agent';
  static const nameClamp = 'name_clamp';
  static const showSla = 'show_sla';
  static const nameClampChars = 'name_clamp_chars';
  static const guideDone = 'guide_done';
}

enum ThemeModeChoice { system, light, dark }

class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  SharedPreferences get raw => _prefs;

  String get themeMode =>
      _prefs.getString(PrefKeys.themeMode) ?? ThemeModeChoice.system.name;

  set themeMode(String v) => _prefs.setString(PrefKeys.themeMode, v);

  String get accentId => _prefs.getString(PrefKeys.accentId) ?? 'terminal';

  set accentId(String v) => _prefs.setString(PrefKeys.accentId, v);

  UiStyle get uiStyle => UiStyle.fromName(_prefs.getString(PrefKeys.uiStyle), UiStyle.kuma);

  set uiStyle(UiStyle v) => _prefs.setString(PrefKeys.uiStyle, v.name);

  String? get localeCode => _prefs.getString(PrefKeys.locale);

  set localeCode(String? v) {
    if (v == null) {
      _prefs.remove(PrefKeys.locale);
    } else {
      _prefs.setString(PrefKeys.locale, v);
    }
  }

  String? get bgImagePath => _prefs.getString(PrefKeys.bgImage);

  set bgImagePath(String? v) {
    if (v == null) {
      _prefs.remove(PrefKeys.bgImage);
    } else {
      _prefs.setString(PrefKeys.bgImage, v);
    }
  }

  double get bgOpacity => _prefs.getDouble(PrefKeys.bgOpacity) ?? 0.85;

  set bgOpacity(double v) => _prefs.setDouble(PrefKeys.bgOpacity, v);

  double get bgBlur => _prefs.getDouble(PrefKeys.bgBlur) ?? 6;

  set bgBlur(double v) => _prefs.setDouble(PrefKeys.bgBlur, v);

  bool get notificationsEnabled => _prefs.getBool(PrefKeys.notifications) ?? true;

  set notificationsEnabled(bool v) => _prefs.setBool(PrefKeys.notifications, v);

  bool get notifyOnDown => _prefs.getBool(PrefKeys.notifyDown) ?? true;

  set notifyOnDown(bool v) => _prefs.setBool(PrefKeys.notifyDown, v);

  bool get notifyOnUp => _prefs.getBool(PrefKeys.notifyUp) ?? true;

  set notifyOnUp(bool v) => _prefs.setBool(PrefKeys.notifyUp, v);

  String get soundId => _prefs.getString(PrefKeys.soundId) ?? 'chime';

  set soundId(String v) => _prefs.setString(PrefKeys.soundId, v);

  int get pollSeconds => _prefs.getInt(PrefKeys.pollSeconds) ?? 60;

  set pollSeconds(int v) => _prefs.setInt(PrefKeys.pollSeconds, v);

  bool get backgroundChecks => _prefs.getBool(PrefKeys.backgroundChecks) ?? true;

  set backgroundChecks(bool v) => _prefs.setBool(PrefKeys.backgroundChecks, v);

  String? get serversJson => _prefs.getString(PrefKeys.servers);

  set serversJson(String v) => _prefs.setString(PrefKeys.servers, v);

  String? get activeServerId => _prefs.getString(PrefKeys.activeServer);

  set activeServerId(String? v) {
    if (v == null) {
      _prefs.remove(PrefKeys.activeServer);
    } else {
      _prefs.setString(PrefKeys.activeServer, v);
    }
  }

  String get iconVariant => _prefs.getString(PrefKeys.iconVariant) ?? 'default';

  set iconVariant(String v) => _prefs.setString(PrefKeys.iconVariant, v);

  String? get customIconPath => _prefs.getString(PrefKeys.customIcon);

  set customIconPath(String? v) =>
      v == null ? _prefs.remove(PrefKeys.customIcon) : _prefs.setString(PrefKeys.customIcon, v);

  String? get customSoundUriValue => _prefs.getString(PrefKeys.customSoundUri);

  set customSoundUriValue(String? v) => v == null
      ? _prefs.remove(PrefKeys.customSoundUri)
      : _prefs.setString(PrefKeys.customSoundUri, v);

  String? get customSoundPath => _prefs.getString(PrefKeys.customSound);

  set customSoundPath(String? v) =>
      v == null ? _prefs.remove(PrefKeys.customSound) : _prefs.setString(PrefKeys.customSound, v);

  bool get uxReport => _prefs.getBool(PrefKeys.uxReport) ?? false;

  set uxReport(bool v) => _prefs.setBool(PrefKeys.uxReport, v);

  bool get dohEnabled => _prefs.getBool(PrefKeys.doh) ?? false;

  set dohEnabled(bool v) => _prefs.setBool(PrefKeys.doh, v);

  /// Custom DoH endpoint, e.g. `https://dns.example.com:8443/dns-query`.
  /// Empty means "use the built-in Cloudflare / Google list".
  String? get dohEndpoint => _prefs.getString(PrefKeys.dohUrl);

  set dohEndpoint(String? v) => v == null || v.trim().isEmpty
      ? _prefs.remove(PrefKeys.dohUrl)
      : _prefs.setString(PrefKeys.dohUrl, v.trim());

  String? get userAgent => _prefs.getString(PrefKeys.userAgent);

  set userAgent(String? v) =>
      v == null || v.isEmpty ? _prefs.remove(PrefKeys.userAgent) : _prefs.setString(PrefKeys.userAgent, v);

  /// Uptime percentages (SLA) are hidden by default: on a phone the per-row
  /// number is noise unless the user asks for it.
  bool get showSla => _prefs.getBool(PrefKeys.showSla) ?? false;

  set showSla(bool v) => _prefs.setBool(PrefKeys.showSla, v);

  bool get nameClamp => _prefs.getBool(PrefKeys.nameClamp) ?? true;

  set nameClamp(bool v) => _prefs.setBool(PrefKeys.nameClamp, v);

  int get nameClampChars => _prefs.getInt(PrefKeys.nameClampChars) ?? 18;

  set nameClampChars(int v) => _prefs.setInt(PrefKeys.nameClampChars, v);

  bool get guideDone => _prefs.getBool(PrefKeys.guideDone) ?? false;

  set guideDone(bool v) => _prefs.setBool(PrefKeys.guideDone, v);
}
