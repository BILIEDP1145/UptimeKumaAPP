import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the management password in the platform keystore so the app can sign
/// back in silently when the session JWT expires.
///
/// The token itself still lives in preferences (it is what the socket uses);
/// the password never goes there. Turning the feature off deletes every entry.
class CredentialStore {
  CredentialStore._();

  // v11 encrypts with the platform keystore by default; the old
  // `encryptedSharedPreferences` flag no longer exists.
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _key(String serverId) => 'uk_pwd_$serverId';

  static Future<void> save(String serverId, String password) async {
    if (password.isEmpty) return;
    try {
      await _storage.write(key: _key(serverId), value: password);
    } catch (_) {
      // Keystore unavailable: silent sign-in just will not work.
    }
  }

  static Future<String?> read(String serverId) async {
    try {
      return await _storage.read(key: _key(serverId));
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String serverId) async {
    try {
      await _storage.delete(key: _key(serverId));
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
