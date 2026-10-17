import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/data/models/server_config.dart';
import 'package:uptime_kuma_app/data/models/share_code.dart';

void main() {
  ServerConfig server({
    String id = 'a',
    String name = 'Prod',
    String url = 'https://status.example.com',
    String slug = 'prod',
    ServerMode mode = ServerMode.monitor,
    String token = 'jwt-secret',
    String apiKey = 'uk1_secret',
    String? collectionId,
    String? collectionName,
  }) {
    return ServerConfig(
      id: id,
      name: name,
      baseUrl: url,
      slug: slug,
      mode: mode,
      token: token,
      apiKey: apiKey,
      colorTag: 'emerald',
      collectionId: collectionId,
      collectionName: collectionName,
    );
  }

  group('instance share code', () {
    test('round-trips the fields the form exposes', () {
      final code = ShareCode.forInstance(server());
      expect(code, startsWith('uptimekuma://instance/'));

      final parsed = ShareCode.parse(code);
      expect(parsed, isNotNull);
      expect(parsed!.isCollection, isFalse);
      expect(parsed.servers, hasLength(1));

      final only = parsed.servers.single;
      expect(only.name, 'Prod');
      expect(only.baseUrl, 'https://status.example.com');
      expect(only.slug, 'prod');
      expect(only.mode, ServerMode.monitor);
      expect(only.colorTag, 'emerald');
    });

    test('never leaks credentials', () {
      final code = ShareCode.forInstance(server());
      expect(code.contains('jwt-secret'), isFalse);
      expect(code.contains('uk1_secret'), isFalse);
      expect(ShareCode.parse(code)!.servers.single.token, isEmpty);
      expect(ShareCode.parse(code)!.servers.single.apiKey, isEmpty);
    });

    test('keeps the collection name so an import lands back in the group', () {
      final code = ShareCode.forInstance(server(), collectionName: 'Home');
      expect(ShareCode.parse(code)!.collectionName, 'Home');
    });

    test('a management instance survives the trip without a session', () {
      final code = ShareCode.forInstance(server(mode: ServerMode.manage));
      final parsed = ShareCode.parse(code)!;
      expect(parsed.servers.single.mode, ServerMode.manage);
      expect(parsed.servers.single.hasSession, isFalse);
    });
  });

  group('collection share code', () {
    test('round-trips every member in order', () {
      final code = ShareCode.forCollection('Prod stack', [
        server(id: 'a', name: 'Alpha', url: 'https://a.example.com'),
        server(id: 'b', name: 'Beta', url: 'https://b.example.com', slug: 'b'),
      ]);
      expect(code, startsWith('uptimekuma://collection/'));

      final parsed = ShareCode.parse(code)!;
      expect(parsed.isCollection, isTrue);
      expect(parsed.collectionName, 'Prod stack');
      expect(parsed.servers.map((s) => s.name).toList(), ['Alpha', 'Beta']);
      expect(parsed.servers.map((s) => s.baseUrl).toList(),
          ['https://a.example.com', 'https://b.example.com']);
    });

    test('each member gets a distinct id', () {
      final parsed = ShareCode.parse(ShareCode.forCollection('X', [
        server(id: 'a', name: 'Same'),
        server(id: 'b', name: 'Same'),
      ]))!;
      final ids = parsed.servers.map((s) => s.id).toSet();
      expect(ids, hasLength(2));
    });
  });

  group('rejects junk', () {
    test('empty, truncated and foreign schemes return null', () {
      expect(ShareCode.parse(''), isNull);
      expect(ShareCode.parse('   '), isNull);
      expect(ShareCode.parse('vless://abc'), isNull);
      expect(ShareCode.parse('uptimekuma://instance/'), isNull);
      expect(ShareCode.parse('uptimekuma://instance/not-base64!!'), isNull);
    });

    test('an instance without a URL is dropped', () {
      // Hand-built payload with a missing url field.
      final broken = ShareCode.parse(
        'uptimekuma://instance/eyJ2IjoxLCJ0eXBlIjoiaW5zdGFuY2UiLCJuYW1lIjoiWCJ9',
      );
      expect(broken, isNull);
    });
  });
}
