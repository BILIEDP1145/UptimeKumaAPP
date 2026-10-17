import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/data/models/server_config.dart';
import 'package:uptime_kuma_app/data/models/status_page.dart';

void main() {
  group('ServerConfig.parseInput', () {
    test('bare host becomes https origin', () {
      final r = ServerConfig.parseInput('status.example.com', slugOverride: 'main');
      expect(r.baseUrl, 'https://status.example.com');
      expect(r.slug, 'main');
    });

    test('full status page url yields slug', () {
      final r = ServerConfig.parseInput('https://status.zakoflare.com/status/zakoflare');
      expect(r.baseUrl, 'https://status.zakoflare.com');
      expect(r.slug, 'zakoflare');
    });

    test('url with port keeps the port', () {
      final r = ServerConfig.parseInput('http://192.168.1.4:3001/status/mon');
      expect(r.baseUrl, 'http://192.168.1.4:3001');
      expect(r.slug, 'mon');
    });

    test('explicit slug wins over path', () {
      final r = ServerConfig.parseInput(
        'https://status.example.com/status/other',
        slugOverride: 'main',
      );
      expect(r.slug, 'main');
    });

    test('encode/decode roundtrip', () {
      const server = ServerConfig(
        id: 'a',
        name: 'Prod',
        baseUrl: 'https://s.example.com',
        slug: 'main',
      );
      final decoded = ServerConfig.decodeList(ServerConfig.encodeList([server]));
      expect(decoded.length, 1);
      expect(decoded.first.name, 'Prod');
      expect(decoded.first.statusPageUrl, 'https://s.example.com/status/main');
    });
  });

  group('Heartbeat.parseKumaTime', () {
    test('parses utc timestamp without zone marker', () {
      final t = Heartbeat.parseKumaTime('2026-10-17 04:18:14.752');
      expect(t.isUtc, isTrue);
      expect(t.year, 2026);
      expect(t.month, 10);
      expect(t.day, 17);
      expect(t.hour, 4);
      expect(t.millisecond, 752);
    });

    test('garbage falls back without throwing', () {
      expect(() => Heartbeat.parseKumaTime('not-a-date'), returnsNormally);
    });
  });

  group('StatusSnapshot', () {
    StatusSnapshot build() {
      return StatusSnapshot(
        config: const StatusPageConfig(slug: 'main', title: 'Demo'),
        groups: const [
          MonitorGroup(
            id: 1,
            name: 'Group',
            monitors: [
              Monitor(id: 10, name: 'API', type: 'http', certExpiryDays: 5, certValid: true),
              Monitor(id: 11, name: 'DB', type: 'port'),
              Monitor(id: 12, name: 'Header', type: 'group'),
            ],
          ),
        ],
        heartbeats: {
          10: [
            Heartbeat(status: MonitorStatus.up, time: DateTime.utc(2026, 10, 17, 1), ping: 120),
            Heartbeat(
              status: MonitorStatus.down,
              time: DateTime.utc(2026, 10, 17, 2),
              msg: 'connection refused',
            ),
          ],
          11: [
            Heartbeat(status: MonitorStatus.up, time: DateTime.utc(2026, 10, 17, 2), ping: 45.5),
          ],
        },
        uptime: const {'10_24': 0.998, '11_24': 1.0},
        fetchedAt: DateTime.utc(2026, 10, 17, 2, 30),
      );
    }

    test('merging two boards keeps ids apart and prefixes group titles', () {
      final merged = StatusSnapshot.merge([
        (label: 'Alpha', snapshot: build()),
        (label: 'Beta', snapshot: build()),
      ]);

      // Two instances, ids overlapping at 10/11 — offsets must separate them.
      final ids = merged.allMonitors.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(merged.allMonitors.length, 4);

      // Groups appear in the order the parts were supplied.
      expect(merged.groups.first.name, 'Alpha · Group');
      expect(merged.groups.last.name, 'Beta · Group');

      // Heartbeats and uptime follow the same offset, or the board goes blank.
      for (final monitor in merged.allMonitors) {
        expect(merged.heartbeatsOf(monitor.id), isNotEmpty);
        expect(merged.uptimeOf(monitor.id, 24), isNotNull);
      }

      // The second copy of the down monitor is still counted as down.
      expect(merged.downCount, 2);
      expect(merged.upCount, 2);
    });

    test('a single part merges to itself without re-offsetting', () {
      final original = build();
      final merged = StatusSnapshot.merge([(label: 'Only', snapshot: original)]);
      expect(identical(merged, original), isTrue);
    });

    test('group headers are excluded from monitors', () {
      final snap = build();
      expect(snap.allMonitors.length, 2);
      expect(snap.allMonitors.any((m) => m.isGroupHeader), isFalse);
    });

    test('status counts derive from last heartbeat', () {
      final snap = build();
      expect(snap.downCount, 1);
      expect(snap.upCount, 1);
      expect(snap.statusOf(10), MonitorStatus.down);
    });

    test('uptime lookup uses id_hours keys', () {
      final snap = build();
      expect(snap.uptimeOf(10, 24), 0.998);
      expect(snap.uptimeOf(10, 720), isNull);
    });

    test('response time skips heartbeats without ping', () {
      final snap = build();
      expect(snap.responseTimeOf(10), 120);
    });

    test('cert warning triggers below threshold', () {
      final snap = build();
      expect(snap.allMonitors.first.hasCertIssue, isTrue);
    });

    test('json roundtrip preserves structure', () {
      final snap = build();
      final restored = StatusSnapshot.fromJson(snap.toJson());
      expect(restored.allMonitors.length, 2);
      expect(restored.heartbeats[10]!.length, 2);
      expect(restored.uptime['10_24'], 0.998);
      expect(restored.statusOf(10), MonitorStatus.down);
    });
  });
}
