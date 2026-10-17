@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/data/api/uk_api.dart';
import 'package:uptime_kuma_app/data/models/server_config.dart';

void main() {
  test('fetchSnapshot hits the real endpoint', () async {
    const server = ServerConfig(
      id: 'default',
      name: 'ZAKOFLARE Status',
      baseUrl: 'https://status.zakoflare.com',
      slug: 'zakoflare',
    );
    final api = UkApi();
    final probe = await api.probe(server);
    // ignore: avoid_print
    print('probe ok=${probe.ok} title=${probe.title} monitors=${probe.monitorCount} msg=${probe.message}');

    final snap = await api.fetchSnapshot(server);
    // ignore: avoid_print
    print('groups=${snap.groups.length} monitors=${snap.allMonitors.length} '
        'hbKeys=${snap.heartbeats.length} uptimeKeys=${snap.uptime.length}');
    expect(snap.allMonitors, isNotEmpty);
    api.dispose();
  });
}
