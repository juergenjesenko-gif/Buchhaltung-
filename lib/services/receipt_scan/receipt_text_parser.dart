import '../../domain/country.dart';
import '../../domain/money.dart';
import '../vat_id/vat_id_format.dart';
import 'ocr_text.dart';

/// Ein erkannter Wert mit Konfidenz 0 bis 100. Die Konfidenz ist eine
/// Heuristik des Parsers, keine Wahrscheinlichkeit der Engine.
class Detected<T> {
  const Detected(this.value, this.confidence);

  final T value;
  final int confidence;

  @override
  String toString() => '$value ($confidence)';
}

/// Umsatzsteuer eines Satzes laut Beleg. Es gilt immer
/// `net + vat == gross` (GR-2), auch wenn nur ein Teil gedruckt war.
class DetectedVat {
  const DetectedVat({
    required this.permille,
    required this.net,
    required this.vat,
    required this.confidence,
  });

  final int permille;
  final Money net;
  final Money vat;
  final int confidence;

  Money get gross => net + vat;
}

/// Alles, was der Parser aus einem Belegtext ermittelt. Jeder Wert ist ein
/// Vorschlag; gebucht wird erst, was die Nutzerin bestätigt (L-2.20).
class ReceiptScanResult {
  const ReceiptScanResult({
    this.date,
    this.gross,
    this.vatLines = const [],
    this.merchant,
    this.vatId,
    this.invoiceNumber,
    required this.currency,
  });

  final Detected<DateTime>? date;

  /// Bruttobetrag in Cent der erkannten [currency] – **nicht** umgerechnet.
  final Detected<Money>? gross;

  /// Ein Eintrag je Steuersatz, absteigend nach Bruttobetrag.
  final List<DetectedVat> vatLines;
  final Detected<String>? merchant;

  /// UID bzw. USt-IdNr. des Ausstellers, normalisiert und formatgeprüft.
  final Detected<String>? vatId;
  final Detected<String>? invoiceNumber;

  /// ISO-4217-Code. Ohne Hinweis auf dem Beleg `EUR` mit geringer Konfidenz.
  final Detected<String> currency;

  bool get isEmpty =>
      date == null &&
      gross == null &&
      vatLines.isEmpty &&
      merchant == null &&
      vatId == null &&
      invoiceNumber == null;

  /// Satz mit dem größten Bruttoanteil, `null` ohne Steuerangabe.
  int? get dominantPermille =>
      vatLines.isEmpty ? null : vatLines.first.permille;
}

/// Liest Belegdatum, Beträge, Steuersätze, Händler, UID, Rechnungsnummer und
/// Währung aus erkanntem Text. Reines Dart, ohne Plattformbezug.
///
/// Die zulässigen Steuersätze kommen aus den [TaxProfile]s (GR-6): zuerst die
/// des eigenen Landes, danach die übrigen, weil auch ausländische Belege
/// eingehen (z. B. Hotel in Deutschland bei österreichischer Nutzerin).
class ReceiptTextParser {
  ReceiptTextParser(this.profile, {DateTime? now, this.ownVatId})
    : now = now ?? DateTime.now();

  final TaxProfile profile;
  final DateTime now;

  /// Eigene UID; wird als Aussteller-UID übergangen (Rechnungen nennen oft
  /// beide).
  final String? ownVatId;

  List<int> get _rates {
    final rates = <int>[
      for (final r in profile.vatRates)
        if (r.permille > 0) r.permille,
    ];
    for (final country in Country.values) {
      for (final r in country.taxProfile.vatRates) {
        if (r.permille > 0 && !rates.contains(r.permille)) {
          rates.add(r.permille);
        }
      }
    }
    return rates;
  }

  ReceiptScanResult parse(OcrDocument document) {
    final rows = [for (final r in document.rows) _fixDigits(r)];
    final currency = _currency(rows);
    final vatLines = _vat(rows);
    var gross = _gross(rows);
    final vatSum = vatLines.map((l) => l.gross).sum;

    if (gross == null && vatLines.isNotEmpty) {
      gross = Detected(vatSum, 50);
    } else if (gross != null && vatLines.isNotEmpty) {
      // Gegenprobe: Summe der Steuerzeilen gleich Gesamtbetrag.
      if ((vatSum - gross.value).cents.abs() <= vatLines.length) {
        gross = Detected(gross.value, 97);
      }
    }

    return ReceiptScanResult(
      date: _date(rows, usDates: currency.value == 'USD'),
      gross: gross,
      vatLines: _reconcile(vatLines, gross),
      merchant: _merchant(rows),
      vatId: _vatId(rows),
      invoiceNumber: _invoiceNumber(rows),
      currency: currency,
    );
  }

  // ---------------------------------------------------------------------
  // Beträge

  static final _amountPattern = RegExp(
    r"(?<![\d.,'])(\d{1,3}(?:[.,']\d{3})+|\d+)[.,](\d{2})(?![\d%])(?!\s?%)(?![.,]\d)",
  );

  /// Parst alle Geldbeträge einer Zeile ganzzahlig in Cent. Erkennt
  /// 1.234,56 · 1,234.56 · 1234.56 · 1'234.56; ein Betrag braucht genau zwei
  /// Nachkommastellen, damit Mengen, Uhrzeiten und Datumsteile nicht als
  /// Beträge gelten.
  static List<Money> amounts(String row) {
    final withoutDates = row.replaceAll(_anyDate, ' ');
    return [
      for (final m in _amountPattern.allMatches(withoutDates))
        Money(
          int.parse(m.group(1)!.replaceAll(RegExp(r"[.,']"), '')) * 100 +
              int.parse(m.group(2)!),
        ),
    ];
  }

  /// Häufige Lesefehler in Zahlen: O statt 0, l/I/| statt 1.
  static String _fixDigits(String row) => row.replaceAllMapped(
    RegExp(r'[0-9OoIl|]{1,7}[.,][0-9OoIl|]{2}(?![A-Za-z])'),
    (m) {
      final s = m.group(0)!;
      if (RegExp(r'\d').allMatches(s).length < 2) return s;
      return s
          .replaceAll(RegExp('[Oo]'), '0')
          .replaceAll(RegExp(r'[Il|]'), '1');
    },
  );

  static final _taxWord = RegExp(
    r'\b(mwst|ust|vat|tax|steuer|umsatzsteuer|mehrwertsteuer|vorsteuer)\b|mwst|ust\.',
  );

  static final _excludeForGross = RegExp(
    r'zwischensumme|subtotal|sub-total|sub total|\bnet(to)?\b|nettobetrag|'
    r'gegeben|rückgeld|rueckgeld|\bchange\b|rabatt|\btip\b|trinkgeld|'
    r'mwst|\bust\b|\bvat\b|\btax\b|steuer|bonus|punkte|ersparnis|gespart',
  );

  static const _strongGross = [
    'zu zahlen',
    'zahlbetrag',
    'gesamtbetrag',
    'endbetrag',
    'rechnungsbetrag',
    'amount due',
    'grand total',
    'total due',
    'balance due',
    'total amount',
  ];

  static const _plainGross = ['summe', 'gesamt', 'total', 'betrag'];

  Detected<Money>? _gross(List<String> rows) {
    Detected<Money>? best;
    for (var i = 0; i < rows.length; i++) {
      final lower = rows[i].toLowerCase();
      if (_excludeForGross.hasMatch(lower)) continue;
      final score = _strongGross.any(lower.contains)
          ? 92
          : _plainGross.any(lower.contains)
          ? 80
          : 0;
      if (score == 0) continue;
      var found = amounts(rows[i]);
      if (found.isEmpty && i + 1 < rows.length) found = amounts(rows[i + 1]);
      if (found.isEmpty) continue;
      final value = found.last;
      if (best == null ||
          score > best.confidence ||
          (score == best.confidence && value > best.value)) {
        best = Detected(value, score);
      }
    }
    if (best != null) return best;

    // Rückfall: größter plausibler Betrag des Belegs.
    Money? largest;
    for (final row in rows) {
      final lower = row.toLowerCase();
      if (RegExp(
        r'gegeben|rückgeld|\bchange\b|iban|\btel\b|\bfax\b',
      ).hasMatch(lower)) {
        continue;
      }
      for (final a in amounts(row)) {
        if (largest == null || a > largest) largest = a;
      }
    }
    return largest == null ? null : Detected(largest, 30);
  }

  // ---------------------------------------------------------------------
  // Umsatzsteuer

  static final _percent = RegExp(r'(?<![\d.,])(\d{1,2})(?:[.,](\d{1,2}))?\s?%');

  int _tolerance(Money vat) => 3 + vat.cents ~/ 100;

  static int _vatOfNet(int net, int p) => (net * p + 500) ~/ 1000;

  static int _vatOfGross(int gross, int p) {
    final net = (gross * 2000 + 1000 + p) ~/ (2 * (1000 + p));
    return gross - net;
  }

  List<DetectedVat> _vat(List<String> rows) {
    final rates = _rates;
    final strong = <int, DetectedVat>{};
    final keyword = <int, DetectedVat>{};
    final itemGross = <int, int>{};

    for (final row in rows) {
      final lower = row.toLowerCase();
      int? permille;
      for (final m in _percent.allMatches(row)) {
        final whole = int.parse(m.group(1)!);
        final frac = m.group(2) == null ? 0 : int.parse(m.group(2)![0]);
        final p = whole * 10 + frac;
        if (rates.contains(p)) {
          permille = p;
          break;
        }
      }
      if (permille == null) continue;
      final p = permille;
      final a = amounts(row).map((m) => m.cents).toList();
      if (a.isEmpty) continue;

      DetectedVat? triple;
      outer:
      for (var i = 0; i < a.length; i++) {
        for (var j = 0; j < a.length; j++) {
          for (var k = 0; k < a.length; k++) {
            if (i == j || j == k || i == k) continue;
            if (a[i] + a[j] == a[k] &&
                (a[j] - _vatOfNet(a[i], p)).abs() <= _tolerance(Money(a[j]))) {
              triple = DetectedVat(
                permille: p,
                net: Money(a[i]),
                vat: Money(a[j]),
                confidence: 95,
              );
              break outer;
            }
          }
        }
      }
      if (triple != null) {
        strong[p] = triple;
        continue;
      }

      DetectedVat? pair;
      for (var i = 0; i < a.length && pair == null; i++) {
        for (var j = 0; j < a.length && pair == null; j++) {
          if (i == j || a[j] == 0) continue;
          final tol = _tolerance(Money(a[j]));
          if (a[j] < a[i] && (a[j] - _vatOfGross(a[i], p)).abs() <= tol) {
            pair = DetectedVat(
              permille: p,
              net: Money(a[i] - a[j]),
              vat: Money(a[j]),
              confidence: 85,
            );
          } else if ((a[j] - _vatOfNet(a[i], p)).abs() <= tol) {
            pair = DetectedVat(
              permille: p,
              net: Money(a[i]),
              vat: Money(a[j]),
              confidence: 85,
            );
          }
        }
      }
      if (pair != null) {
        strong[p] = pair;
        continue;
      }

      if (_taxWord.hasMatch(lower)) {
        final vat = a.last;
        keyword[p] = DetectedVat(
          permille: p,
          net: Money((vat * 1000 + p ~/ 2) ~/ p),
          vat: Money(vat),
          confidence: 45,
        );
      } else {
        // Positionszeile mit Satzangabe: Bruttobeträge je Satz summieren.
        itemGross[p] = (itemGross[p] ?? 0) + a.last;
      }
    }

    final result = <int, DetectedVat>{};
    itemGross.forEach((p, g) {
      final vat = _vatOfGross(g, p);
      result[p] = DetectedVat(
        permille: p,
        net: Money(g - vat),
        vat: Money(vat),
        confidence: 40,
      );
    });
    result.addAll(keyword);
    result.addAll(strong);
    return result.values.toList()..sort((x, y) => y.gross.compareTo(x.gross));
  }

  /// Bei nur einem Satz mit unsicherer Herkunft gilt der Gesamtbetrag: Netto
  /// und Steuer werden daraus gerechnet, damit GR-2 hält.
  List<DetectedVat> _reconcile(
    List<DetectedVat> lines,
    Detected<Money>? gross,
  ) {
    if (lines.length != 1 || gross == null) return lines;
    final line = lines.single;
    if (line.gross == gross.value || line.confidence >= 85) return lines;
    final vat = _vatOfGross(gross.value.cents, line.permille);
    return [
      DetectedVat(
        permille: line.permille,
        net: Money(gross.value.cents - vat),
        vat: Money(vat),
        confidence: 60,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Datum

  static final _anyDate = RegExp(
    r'\b\d{1,2}[./]\d{1,2}[./](\d{4}|\d{2})\b|\b\d{4}-\d{2}-\d{2}\b',
  );

  static const _months = {
    'jan': 1, 'feb': 2, 'mär': 3, 'maer': 3, 'mar': 3, 'apr': 4, 'mai': 5, //
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'okt': 10, 'oct': 10,
    'nov': 11, 'dez': 12, 'dec': 12,
  };

  static final _numericDate = RegExp(
    r'(?<!\d)(\d{1,2})([./])(\d{1,2})\2(\d{4}|\d{2})(?!\d)',
  );
  static final _isoDate = RegExp(r'(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)');
  static final _textDate = RegExp(
    r'(?<!\d)(\d{1,2})\.?\s*(jan|feb|mär|maer|mar|apr|mai|may|jun|jul|aug|sep|okt|oct|nov|dez|dec)[a-zä]*\.?,?\s*(\d{4})',
    caseSensitive: false,
  );
  static final _englishDate = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})',
    caseSensitive: false,
  );

  DateTime? _valid(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    if (date.month != m || date.day != d) return null;
    if (date.isAfter(now.add(const Duration(days: 1)))) return null;
    if (date.isBefore(DateTime(now.year - 10))) return null;
    return date;
  }

  Detected<DateTime>? _date(List<String> rows, {required bool usDates}) {
    Detected<DateTime>? best;
    for (final row in rows) {
      final lower = row.toLowerCase();
      var score = RegExp(r'datum|date|ausgestellt').hasMatch(lower) ? 92 : 75;
      if (RegExp(
        r'fällig|faellig|due|gültig|mhd|lieferzeitraum|zahlbar bis|leistungszeitraum',
      ).hasMatch(lower)) {
        score = 40;
      }
      final found = <DateTime>[];
      for (final m in _numericDate.allMatches(row)) {
        final a = int.parse(m.group(1)!);
        final b = int.parse(m.group(3)!);
        final y = int.parse(m.group(4)!);
        final date = usDates && m.group(2) == '/'
            ? _valid(y, a, b) ?? _valid(y, b, a)
            : _valid(y, b, a);
        if (date != null) found.add(date);
      }
      for (final m in _isoDate.allMatches(row)) {
        final date = _valid(
          int.parse(m.group(1)!),
          int.parse(m.group(2)!),
          int.parse(m.group(3)!),
        );
        if (date != null) found.add(date);
      }
      for (final m in _textDate.allMatches(row)) {
        final month = _months[m.group(2)!.toLowerCase()];
        if (month == null) continue;
        final date = _valid(
          int.parse(m.group(3)!),
          month,
          int.parse(m.group(1)!),
        );
        if (date != null) found.add(date);
      }
      for (final m in _englishDate.allMatches(row)) {
        final month = _months[m.group(1)!.toLowerCase()];
        if (month == null) continue;
        final date = _valid(
          int.parse(m.group(3)!),
          month,
          int.parse(m.group(2)!),
        );
        if (date != null) found.add(date);
      }
      if (found.isEmpty) continue;
      if (best == null || score > best.confidence) {
        best = Detected(found.first, score);
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------
  // Händler, UID, Rechnungsnummer, Währung

  static final _notMerchant = RegExp(
    r'rechnung|invoice|receipt|quittung|beleg|kassa|kasse|\bbon\b|datum|date|'
    r'\btel\b|\bfax\b|www|http|@|\buid\b|\bust\b|steuer|str\.|straße|strasse|gasse|platz|weg\b|'
    r'filiale|willkommen|welcome|danke|kopie|original|seite|page',
  );

  Detected<String>? _merchant(List<String> rows) {
    for (var i = 0; i < rows.length && i < 6; i++) {
      final row = rows[i].trim();
      final letters = RegExp(r'[A-Za-zÄÖÜäöüß]').allMatches(row).length;
      if (letters < 3 || letters * 2 < row.length) continue;
      if (RegExp(r'^\d').hasMatch(row)) continue;
      if (_notMerchant.hasMatch(row.toLowerCase())) continue;
      final legalForm = RegExp(
        r'\b(gmbh|ag|kg|og|e\.u\.|e\.k\.|ltd|inc|llc|se|co)\b',
        caseSensitive: false,
      ).hasMatch(row);
      final name = row.replaceAll(RegExp(r'\s{2,}'), ' ');
      return Detected(name, legalForm ? 75 : (i == 0 ? 60 : 45));
    }
    return null;
  }

  static final _vatIdPattern = RegExp(
    r'(ATU[0-9OIL]{8}|DE[0-9OIL]{9}|(?:BE|BG|CY|CZ|DK|EE|EL|ES|FI|FR|HR|HU|IE|IT|LT|LU|LV|MT|NL|PL|PT|RO|SE|SI|SK)[0-9A-Z]{8,12})',
  );

  Detected<String>? _vatId(List<String> rows) {
    final own = ownVatId == null ? null : VatIdFormat.normalize(ownVatId!);
    for (final row in rows) {
      final compact = VatIdFormat.normalize(row.replaceAll(':', ' '));
      for (final m in _vatIdPattern.allMatches(compact)) {
        var candidate = m.group(0)!;
        final code = candidate.startsWith('ATU')
            ? 'ATU'
            : candidate.substring(0, 2);
        if (code == 'ATU' || code == 'DE') {
          candidate =
              code +
              candidate
                  .substring(code.length)
                  .replaceAll('O', '0')
                  .replaceAll(RegExp('[IL]'), '1');
        } else {
          final digits = RegExp(r'\d').allMatches(candidate).length;
          if (digits < 7 ||
              !RegExp(
                r'uid|ust|vat|tva|iva|mwst|btw|moms|steuer',
                caseSensitive: false,
              ).hasMatch(row)) {
            continue;
          }
        }
        if (candidate == own) continue;
        if (VatIdFormat.check(candidate) != null) continue;
        final withChecksum = code == 'ATU' || code == 'DE';
        return Detected(candidate, withChecksum ? 95 : 70);
      }
    }
    return null;
  }

  static final _invoiceLabel = RegExp(
    r'(rechnungs?\s*-?\s*(?:nr|nummer|no)|re\.?\s*-?\s*nr|invoice\s*(?:no|number|nr|#)|'
    r'beleg\s*-?\s*(?:nr|nummer)|bon\s*-?\s*(?:nr|nummer)|quittung\s*-?\s*nr)\.?\s*[:#]?\s*',
    caseSensitive: false,
  );

  Detected<String>? _invoiceNumber(List<String> rows) {
    final token = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/_.]*');
    for (var i = 0; i < rows.length; i++) {
      final m = _invoiceLabel.firstMatch(rows[i]);
      if (m == null) continue;
      var rest = rows[i].substring(m.end).trim();
      if (rest.isEmpty && i + 1 < rows.length) rest = rows[i + 1].trim();
      final t = token
          .firstMatch(rest)
          ?.group(0)
          ?.replaceAll(RegExp(r'[.]$'), '');
      if (t == null || !RegExp(r'\d').hasMatch(t)) continue;
      final strong = RegExp(
        'rechnung|invoice|re',
        caseSensitive: false,
      ).hasMatch(m.group(1)!);
      return Detected(t, strong ? 85 : 70);
    }
    return null;
  }

  static const isoCurrencies = {
    'EUR', 'USD', 'CHF', 'GBP', 'CZK', 'HUF', 'PLN', 'SEK', 'DKK', 'NOK', //
    'JPY', 'CAD', 'AUD', 'CNY', 'TRY', 'RON', 'BGN', 'RSD', 'BAM',
  };

  Detected<String> _currency(List<String> rows) {
    final counts = <String, int>{};
    void add(String code) => counts[code] = (counts[code] ?? 0) + 1;
    for (final row in rows) {
      for (final m in RegExp(r'\b([A-Z]{3})\b').allMatches(row)) {
        if (isoCurrencies.contains(m.group(1))) add(m.group(1)!);
      }
      for (final _ in '€'.allMatches(row)) {
        add('EUR');
      }
      for (final _ in '£'.allMatches(row)) {
        add('GBP');
      }
      for (final _ in RegExp(r'(?<![A-Z])\$|US\$').allMatches(row)) {
        add('USD');
      }
      if (RegExp(r'\bS?Fr\.\s?\d').hasMatch(row)) add('CHF');
    }
    if (counts.isEmpty) return const Detected('EUR', 40);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Detected(sorted.first.key, counts.length == 1 ? 90 : 60);
  }
}
