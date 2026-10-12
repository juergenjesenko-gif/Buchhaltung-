import 'dart:convert';
import 'dart:io';

import 'currency_converter.dart';

/// Ein EZB-Referenzkurs: Einheiten von [currency] je 1 Euro × 10^6.
class EcbRate {
  const EcbRate(this.date, this.currency, this.rateMicros);

  final DateTime date;
  final String currency;
  final int rateMicros;

  @override
  bool operator ==(Object other) =>
      other is EcbRate &&
      other.date == date &&
      other.currency == currency &&
      other.rateMicros == rateMicros;

  @override
  int get hashCode => Object.hash(date, currency, rateMicros);
}

/// Liefert den Text unter [uri]. Austauschbar, damit Tests ohne Netz laufen.
typedef EcbTransport = Future<String> Function(Uri uri);

/// Abruf der EZB-Referenzkurse (`eurofxref`). Direkt vom Gerät, ohne Server
/// des Anbieters, **nur auf Knopfdruck** (L-19.29). Muster wie `ViesClient`.
class EcbClient {
  EcbClient({EcbTransport? transport})
    : _transport = transport ?? _httpTransport;

  final EcbTransport _transport;

  /// Letzte 90 Tage – genügt für den laufenden und den Vormonat.
  static final last90Days = Uri.parse(
    'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml',
  );

  /// Gesamte Historie seit 1999 (einige MB) – nur für ältere Belege.
  static final history = Uri.parse(
    'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.xml',
  );

  /// Wählt die kleinste Datei, die [date] noch enthält.
  static Uri sourceFor(DateTime date, DateTime today) =>
      today.difference(date).inDays <= 80 ? last90Days : history;

  Future<List<EcbRate>> fetch(Uri uri) async => parse(await _transport(uri));

  /// Liest das eurofxref-XML ohne XML-Bibliothek. Das Format ist seit 1999
  /// unverändert: `<Cube time="YYYY-MM-DD">` umschließt
  /// `<Cube currency="USD" rate="1.0823"/>`. Ein eigener, enger Parser erspart
  /// eine Abhängigkeit (CLAUDE.md: jede Abhängigkeit weniger zählt).
  static List<EcbRate> parse(String xml) {
    final result = <EcbRate>[];
    final day = RegExp(
      r'''<Cube\s+time=["'](\d{4})-(\d{2})-(\d{2})["']\s*>(.*?)</Cube>''',
      dotAll: true,
    );
    final rate = RegExp(
      r'''<Cube\s+currency=["']([A-Z]{3})["']\s+rate=["']([0-9.]+)["']\s*/>''',
    );
    for (final d in day.allMatches(xml)) {
      final date = DateTime.utc(
        int.parse(d.group(1)!),
        int.parse(d.group(2)!),
        int.parse(d.group(3)!),
      );
      for (final r in rate.allMatches(d.group(4)!)) {
        final micros = CurrencyConverter.parseRate(r.group(2)!);
        if (micros != null) result.add(EcbRate(date, r.group(1)!, micros));
      }
    }
    return result;
  }

  static Future<String> _httpTransport(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/xml');
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('EZB antwortet mit ${response.statusCode}');
      }
      return text;
    } finally {
      client.close();
    }
  }
}
