// Link-QR (L-27.7): nur https, nur bestätigte Domain, nur PDF/XML,
// Größenlimit; Hinweisstreifen einhändig bedienbar (≥ 48 dp).
import 'dart:convert';
import 'dart:typed_data';

import 'package:buchhaltung/features/receipts/link_invoice_strip.dart';
import 'package:buchhaltung/services/link_invoice/link_invoice_fetcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements LinkTransport {
  _Fake(this.responses);
  final Map<String, LinkResponse> responses;
  final requested = <Uri>[];

  @override
  Future<LinkResponse> get(Uri uri, int maxBytes) async {
    requested.add(uri);
    final r = responses[uri.toString()];
    if (r == null) throw StateError('unerwartet: $uri');
    if (r.body.length > maxBytes) throw const LinkTooLarge();
    return r;
  }
}

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  final pdf = _b('%PDF-1.7\n...');

  test('PDF von der bestätigten Domain', () async {
    final t = _Fake({
      'https://rechnung.example.at/r/1': LinkResponse(status: 200, body: pdf),
    });
    final r = await LinkInvoiceFetcher(transport: t).fetch(
      Uri.parse('https://rechnung.example.at/r/1'),
      confirmedHost: 'rechnung.example.at',
    );
    expect(r, isA<LinkFile>());
    expect((r as LinkFile).kind, 'pdf');
  });

  test(
    'Weiterleitung auf gleiche Domain folgt, fremde Domain fragt neu',
    () async {
      final t = _Fake({
        'https://a.example.at/1': LinkResponse(
          status: 302,
          body: Uint8List(0),
          location: '/2',
        ),
        'https://a.example.at/2': LinkResponse(
          status: 302,
          body: Uint8List(0),
          location: 'https://evil.example.com/x',
        ),
      });
      final r = await LinkInvoiceFetcher(transport: t).fetch(
        Uri.parse('https://a.example.at/1'),
        confirmedHost: 'a.example.at',
      );
      expect(r, isA<LinkRedirect>());
      expect((r as LinkRedirect).target.host, 'evil.example.com');
      // Die fremde Domain wurde NICHT angefragt.
      expect(t.requested.map((u) => u.host).toSet(), {'a.example.at'});
    },
  );

  test('HTML-Seite: Browser statt Laden', () async {
    final t = _Fake({
      'https://portal.example.at/': LinkResponse(
        status: 200,
        body: _b('<!doctype html><html>Login</html>'),
        contentType: 'text/html',
      ),
    });
    final r = await LinkInvoiceFetcher(transport: t).fetch(
      Uri.parse('https://portal.example.at/'),
      confirmedHost: 'portal.example.at',
    );
    expect(r, isA<LinkNeedsBrowser>());
  });

  test('XML-Rechnung wird erkannt', () async {
    final t = _Fake({
      'https://x.example.at/r.xml': LinkResponse(
        status: 200,
        body: _b('<?xml version="1.0"?><Invoice/>'),
        contentType: 'application/xml',
      ),
    });
    final r = await LinkInvoiceFetcher(transport: t).fetch(
      Uri.parse('https://x.example.at/r.xml'),
      confirmedHost: 'x.example.at',
    );
    expect((r as LinkFile).kind, 'xml');
  });

  test('nur https, Größenlimit', () async {
    final t = _Fake({
      'https://big.example.at/': LinkResponse(
        status: 200,
        body: Uint8List(LinkInvoiceFetcher.maxBytes + 1),
      ),
    });
    final f = LinkInvoiceFetcher(transport: t);
    expect(
      await f.fetch(
        Uri.parse('http://big.example.at/'),
        confirmedHost: 'big.example.at',
      ),
      isA<LinkRejected>(),
    );
    expect(
      await f.fetch(
        Uri.parse('https://big.example.at/'),
        confirmedHost: 'big.example.at',
      ),
      isA<LinkRejected>(),
    );
  });

  testWidgets('Streifen: Domain groß, Knöpfe mindestens 48 dp', (tester) async {
    var loaded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LinkInvoiceStrip(
            domain: 'rechnung.example.at',
            onLoad: () => loaded = true,
            onBrowser: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    expect(find.text('rechnung.example.at'), findsOneWidget);
    for (final label in ['Laden', 'Im Browser öffnen']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final close = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(IconButton),
      ),
    );
    expect(close.height, greaterThanOrEqualTo(48));
    expect(loaded, isFalse, reason: 'nichts ohne Tipp laden');
    await tester.tap(find.text('Laden'));
    expect(loaded, isTrue);
  });
}
