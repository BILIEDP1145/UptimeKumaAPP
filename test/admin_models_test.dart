import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/data/models/admin_models.dart';

/// Guards the wire format of the Socket.IO payloads. Uptime Kuma stores the
/// notification bindings and the accepted status codes in two different shapes
/// (map vs JSON string), so a careless round-trip silently wipes them.
void main() {
  test('a new monitor sends the field set the web UI sends', () {
    final draft = MonitorDraft(
      name: '  API  ',
      url: ' https://api.example.com/health ',
      interval: 30,
      notificationIds: const [3, 7],
    );

    final payload = draft.toPayload();

    expect(payload['name'], 'API');
    expect(payload['type'], 'http');
    expect(payload['url'], 'https://api.example.com/health');
    expect(payload['method'], 'GET');
    expect(payload['interval'], 30);
    expect(payload['active'], 1);
    expect(payload['upsideDown'], 0);
    expect(payload['notificationIDList'], {'3': true, '7': true});
    expect(payload['accepted_statuscodes'], ['200-299']);
    expect(payload.containsKey('accepted_statuscodes_json'), isFalse);
    expect(payload.containsKey('id'), isFalse);
  });

  test('editing keeps server-owned fields and re-shapes the two odd columns', () {
    final row = <String, dynamic>{
      'id': 12,
      'name': 'Old name',
      'type': 'keyword',
      'url': 'https://example.com',
      'keyword': 'sign in',
      'interval': 60,
      'accepted_statuscodes_json': '["200-299","301"]',
      'notificationIDList': {'4': true, '9': false},
      'maxretries': 2,
      // A field the form never exposes; it must survive the round-trip.
      'httpBodyEncoding': 'json',
      'resendInterval': 5,
    };

    final draft = MonitorDraft.fromRow(row);

    expect(draft.id, 12);
    expect(draft.kind, MonitorKind.keyword);
    expect(draft.acceptedCodes, ['200-299', '301']);
    expect(draft.notificationIds, [4]);

    final payload = draft.toPayload();

    expect(payload['id'], 12);
    expect(payload['httpBodyEncoding'], 'json');
    expect(payload['keyword'], 'sign in');
    expect(payload['accepted_statuscodes'], ['200-299', '301']);
    expect(payload['notificationIDList'], {'4': true});
    expect(payload.containsKey('accepted_statuscodes_json'), isFalse);
  });

  test('non-HTTP kinds never carry a URL or status-code list', () {
    final draft = MonitorDraft(
      kind: MonitorKind.ping,
      name: 'edge',
      url: 'https://leftover.example.com',
      hostname: ' 10.0.0.1 ',
      acceptedCodes: const ['404'],
    );

    final payload = draft.toPayload();

    expect(payload['hostname'], '10.0.0.1');
    expect(payload['accepted_statuscodes'], ['200-299']);
    expect(payload['url'], isNot('https://leftover.example.com'));
  });

  test('group monitors blank the target so Kuma does not probe them', () {
    final payload = MonitorDraft(kind: MonitorKind.group, name: 'CN nodes').toPayload();

    expect(payload['type'], 'group');
    expect(payload['url'], '');
    expect(payload['hostname'], '');
  });

  test('provider specs address the fields Kuma expects', () {
    for (final spec in NotificationProviderSpec.all) {
      expect(spec.fields, isNotEmpty, reason: '${spec.type} has no fields');
      for (final field in spec.fields) {
        expect(field.key.trim(), isNotEmpty);
      }
    }
    expect(NotificationProviderSpec.byType('telegram')?.fields.first.key,
        'telegramBotToken');
    expect(NotificationProviderSpec.byType('nope'), isNull);
  });
}
