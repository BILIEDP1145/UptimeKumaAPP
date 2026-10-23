@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/data/net/uk_http.dart';

/// Live checks against real resolvers and a real Cloudflare-fronted host.
///
/// The second test exists because of a bug that had nothing to do with DNS:
/// `HttpClient.connectionFactory` sockets are used as-is, so returning a plain
/// TCP socket there sent unencrypted HTTP to port 443 and Cloudflare answered
/// "400 The plain HTTP request was sent to HTTPS port". DoH looked broken while
/// the resolver was fine all along.
void main() {
  test('custom public DoH endpoints resolve', () async {
    for (final endpoint in const [
      'https://dns.alidns.com/dns-query',
      'https://doh.pub/dns-query',
      'https://doh.zakoflare.com/dns-query',
    ]) {
      final ip = await DohResolver.resolve(
        'status.zakoflare.com',
        endpoint: endpoint,
      );
      // ignore: avoid_print
      print('$endpoint -> $ip');
      expect(ip, isNot('status.zakoflare.com'), reason: endpoint);
    }
  });

  test('HTTPS through DoH behaves exactly like the system resolver', () async {
    const target = 'https://status.wsmdn.top/api/status-page/status';

    Future<int> status({required bool doh}) async {
      final client = UkHttp.build(
        doh: doh,
        dohEndpoint: 'https://dns.alidns.com/dns-query',
      );
      try {
        final res = await client.get(Uri.parse(target));
        return res.statusCode;
      } finally {
        client.close();
      }
    }

    final direct = await status(doh: false);
    final tunnelled = await status(doh: true);
    // ignore: avoid_print
    print('direct=$direct doh=$tunnelled');
    expect(tunnelled, direct);
    expect(tunnelled, isNot(400), reason: 'plain HTTP was sent to port 443');
  });
}
