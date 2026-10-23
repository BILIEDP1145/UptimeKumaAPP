import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/data/api/uk_socket.dart';
import 'package:uptime_kuma_app/data/models/admin_models.dart';
import 'package:uptime_kuma_app/data/models/server_config.dart';

/// End-to-end check of the management protocol against a throwaway container:
///
/// ```bash
/// docker run -d --name uk-test -p 3001:3001 \
///   -e UPTIME_KUMA_DB_TYPE=sqlite louislam/uptime-kuma:2
/// flutter test test/admin_e2e_test.dart \
///   --dart-define=E2E_BASE=http://127.0.0.1:3001
/// ```
///
/// It is skipped in a normal run, so `flutter test` stays offline and fast.
const String _base = String.fromEnvironment('E2E_BASE');

void main() {
  if (_base.isEmpty) {
    test('management e2e (skipped: pass --dart-define=E2E_BASE)', () {}, skip: true);
    return;
  }

  const username = 'admin';
  const password = 'ZakoFlare2026';
  // Keep leftovers from earlier runs out of the way.
  final tag = DateTime.now().millisecondsSinceEpoch % 1000000;
  final monitorName = 'e2e probe $tag';
  final hookName = 'e2e hook $tag';

  test('create account, then CRUD a monitor over Socket.IO', () async {
    // 1. First-run account creation. `setup` takes two positional args, which
    // the client spreads from a list.
    final bootstrap = UkSocket(baseUrl: _base);
    await bootstrap.connect();
    final created = await bootstrap.ack('setup', [username, password], const Duration(seconds: 20));
    bootstrap.dispose();
    // {ok:true} on a fresh instance; {ok:false, msg:"..."} if it already exists.
    expect(created, isA<Map>());

    final server = ServerConfig(
      id: 'e2e',
      name: 'e2e',
      baseUrl: _base,
      mode: ServerMode.manage,
    );
    final admin = UkAdmin(server);
    addTearDown(admin.dispose);

    // 2. Password login returns the JWT we persist instead of the password.
    final login = await admin.signIn(username: username, password: password);
    expect(login.ok, isTrue, reason: login.message);
    expect(login.token, isNotNull);
    expect(login.token, isNotEmpty);

    // 3. A wrong password must surface as a friendly message, not a crash.
    final rejected = await UkAdmin(server).signIn(username: username, password: 'nope');
    expect(rejected.ok, isFalse);
    expect(rejected.message, isNotNull);

    // 4. Add a monitor with exactly the payload the edit form would send.
    final draft = MonitorDraft(
      name: monitorName,
      url: 'https://example.com',
      interval: 60,
      acceptedCodes: const ['200-299', '301'],
    );
    await admin.addMonitor(draft.toPayload());

    var data = await admin.fetch();
    final created2 = data.monitors.values
        .where((m) => m['name'] == monitorName)
        .toList();
    expect(created2, hasLength(1), reason: 'monitor not visible after add');

    final monitor = AdminMonitor(created2.single);
    expect(monitor.kind, MonitorKind.http);
    expect(monitor.target, 'https://example.com');

    // Kuma stores the codes as a JSON string column; the round-trip must keep
    // both entries and hand them back as a list.
    final reread = MonitorDraft.fromRow(created2.single);
    expect(reread.acceptedCodes, containsAll(<String>['200-299', '301']));

    // 5. Pause / resume.
    await admin.setMonitorActive(monitor.id, false);
    data = await admin.fetch();
    expect(AdminMonitor(data.monitors[monitor.id]!).active, isFalse);
    await admin.setMonitorActive(monitor.id, true);

    // 6. Edit keeps notification bindings and unknown columns intact.
    final edit = MonitorDraft.fromRow(data.monitors[monitor.id]!)
      ..name = '$monitorName renamed'
      ..interval = 120;
    await admin.editMonitor(edit.toPayload());
    data = await admin.fetch();
    expect(AdminMonitor(data.monitors[monitor.id]!).name, '$monitorName renamed');
    expect(AdminMonitor(data.monitors[monitor.id]!).interval, 120);

    // 7. Notification provider, then delete both.
    await admin.addNotification({
      'name': hookName,
      'type': 'webhook',
      'isDefault': false,
      'applyExisting': false,
      'webhookURL': 'https://example.com/hook',
      'webhookContentType': 'json',
      'webhookJSONBody': '{}',
      'webhookAdditionalHeaders': '{}',
    });
    data = await admin.fetch();
    final hook = data.notifications.where((n) => n['name'] == hookName).toList();
    expect(hook, hasLength(1));
    await admin.deleteNotification((hook.single['id'] as num).toInt());

    // 8. Status page + incident (slug-addressed in Kuma 2.x).
    final pageSlug = 'e2e-page-$tag';
    await admin.addStatusPage(title: 'e2e page $tag', slug: pageSlug);
    data = await admin.fetch();
    expect(
      data.statusPages.any((p) => p['slug'] == pageSlug),
      isTrue,
      reason: 'status page list did not include the new page',
    );
    await admin.postIncident(
      slug: pageSlug,
      title: 'e2e incident $tag',
      content: 'created by the mobile client',
      style: 'info',
    );
    await admin.unpinIncident(pageSlug);

    await admin.deleteMonitor(monitor.id);
    data = await admin.fetch();
    expect(data.monitors.containsKey(monitor.id), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
