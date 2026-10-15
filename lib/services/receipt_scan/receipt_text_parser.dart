import '../../domain/country.dart';
import '../../domain/money.dart';
import '../vat_id/vat_id_format.dart';
import 'ocr_text.dart';
import 'receipt_classifier.dart';
import 'receipt_keywords.dart';

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
    for (final p in euRates) {
      if (!rates.contains(p)) rates.add(p);
    }
    return rates;
  }

  ReceiptScanResult parse(OcrDocument document) {
    final rows = [for (final r in document.rows) _fixDigits(r)];
    final currency = _currency(rows);
    final vatLines = _vat(rows);
    var gross = _gross(rows);
    final vatSum = vatLines.map((l) => l.gross).sum;

    final vatProven =
        vatLines.isNotEmpty && vatLines.every((l) => l.confidence >= 85);
    final vatSumPrinted =
        vatProven && rows.any((r) => amounts(r).contains(vatSum));
    if (gross == null && vatLines.isNotEmpty) {
      gross = Detected(vatSum, vatSumPrinted ? 90 : 50);
    } else if (gross != null && vatLines.isNotEmpty) {
      // Gegenprobe: Summe der Steuerzeilen gleich Gesamtbetrag.
      if ((vatSum - gross.value).cents.abs() <= vatLines.length) {
        gross = Detected(gross.value, 97);
      } else if (vatProven && (vatSumPrinted || gross.confidence < 60)) {
        // Rechnerisch geprüfte Steuerzeilen (Netto + Steuer = Brutto) gehen
        // einem unsicheren Gesamtbetrag vor, z. B. wenn der Daumen „Summe“
        // verdeckt und nur „Bar 9,00“ lesbar ist (SPAR-Bon im Korpus).
        gross = Detected(vatSum, vatSumPrinted ? 90 : 70);
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

  /// Häufige Lesefehler in Zahlen: O statt 0, l/I/| statt 1; Leerzeichen
  /// nach dem Dezimalkomma („685, 88 kr“, ML Kit auf Thermopapier).
  static String _fixDigits(String row) => row
      .replaceAllMapped(
        RegExp(r'(?<![\d.,])(\d{1,3}(?:\.\d{3})*|\d+)([.,]) (\d{2})(?![\d.,])'),
        (m) => '${m.group(1)}${m.group(2)}${m.group(3)}',
      )
      .replaceAllMapped(
        RegExp(r'[0-9OoIl|]{1,7}[.,][0-9OoIl|]{2}(?![A-Za-z])'),
        (m) {
          final s = m.group(0)!;
          if (RegExp(r'\d').allMatches(s).length < 2) return s;
          return s
              .replaceAll(RegExp('[Oo]'), '0')
              .replaceAll(RegExp(r'[Il|]'), '1');
        },
      );

  static bool _taxWord(String lower) =>
      ReceiptKeywords.any(ReceiptKeywords.tax, lower);

  /// Zeilen, die zwar „Summe/Total“ enthalten können, aber nicht den
  /// Gesamtbetrag tragen (Zwischensumme, Netto, Steuer, Rückgeld …).
  static final _excludeForGross = RegExp(
    r'zwischensumme|subtotal|sub-total|sub total|'
    r'gegeben|rückgeld|rueckgeld|\bchange\b|rabatt|\btip\b|trinkgeld|'
    r'bonus|punkte|ersparnis|gespart|vračilo|vracilo|resto|visszajáró',
  );

  static bool _notGrossRow(String lower) =>
      _excludeForGross.hasMatch(lower) ||
      ReceiptKeywords.any(ReceiptKeywords.net, lower) ||
      ReceiptKeywords.any(ReceiptKeywords.tax, lower) ||
      _percent.hasMatch(lower) ||
      _percentAfter.hasMatch(lower);

  Detected<Money>? _gross(List<String> rows) {
    Detected<Money>? best;
    for (var i = 0; i < rows.length; i++) {
      final lower = rows[i].toLowerCase();
      if (_notGrossRow(lower)) continue;
      final score = ReceiptKeywords.weightIn(ReceiptKeywords.gross, lower);
      if (score == 0) continue;
      var found = amounts(rows[i]);
      if (found.isEmpty && i + 1 < rows.length) found = amounts(rows[i + 1]);
      if (found.isEmpty && i + 1 < rows.length) {
        // Betrag ohne Nachkommastellen allein in der Folgezeile, z. B.
        // „Total,$): / 1415“ (Taxi Taiwan): nur direkt nach dem Schlüsselwort.
        final whole = RegExp(
          r'^\$?\s?(\d{1,6})$',
        ).firstMatch(rows[i + 1].trim());
        if (whole != null) {
          final value = Money(int.parse(whole.group(1)!) * 100);
          if (best == null || 60 > best.confidence) best = Detected(value, 60);
        }
        continue;
      }
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

  /// Satz nach dem Prozentzeichen („DDV % 22,0“, slowenische Belege).
  static final _percentAfter = RegExp(
    r'%\s*[:]?\s*(\d{1,2})(?:[.,](\d{1,2}))?(?![\d.,]?\d)',
  );

  /// Ein plausibler Steuersatz in Promille: ein bekannter aus den Profilen
  /// oder den EU-Sätzen, oder ein beliebiger zwischen 1 und 30 %, der dann
  /// nur mit Rechenprobe (Netto + Steuer = Brutto) gilt. Liefert den Satz und
  /// die Zeile ohne Satzangabe, damit „22,00“ nicht als Betrag zählt.
  (int, String)? _rateIn(String row, List<int> rates) {
    (int, String)? fallback;
    for (final pattern in [_percent, _percentAfter]) {
      for (final m in pattern.allMatches(row)) {
        final whole = int.parse(m.group(1)!);
        final frac = m.group(2) == null ? 0 : int.parse(m.group(2)![0]);
        final p = whole * 10 + frac;
        if (p < 10 || p > 300) continue;
        final rest = row.replaceRange(m.start, m.end, ' ');
        if (rates.contains(p)) return (p, rest);
        fallback ??= (p, rest);
      }
    }
    return fallback;
  }

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
      final rate = _rateIn(row, rates);
      if (rate == null) continue;
      final (p, rest) = rate;
      final known = rates.contains(p);
      final a = amounts(rest).map((m) => m.cents).toList();
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

      if (!known) continue;
      if (_taxWord(lower)) {
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

    if (strong.isEmpty) {
      final table = _vatTable(rows);
      if (table != null) strong[table.permille] = table;
    }
    final result = <int, DetectedVat>{};
    if (strong.isEmpty && keyword.isEmpty) {
      final included = _includedVat(rows);
      if (included != null) strong[included.permille] = included;
    }
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

  /// Steuertabelle mit Kopfzeile („DDV % | Osnova | Znesek DDV | Skupaj“)
  /// und Werten in den Zeilen darunter, der Satz ohne Prozentzeichen
  /// („22,0  1,62  9,00“, Basis eine Zeile tiefer). Die Zeilen sind schon
  /// über die Lage zusammengeführt; die Spalten werden über die Rechenprobe
  /// zugeordnet (Netto + Steuer = Brutto, Steuer = Netto × Satz), weil ML Kit
  /// die Kopfwörter auf Thermopapier oft entstellt („00Y“, „DOV“).
  DetectedVat? _vatTable(List<String> rows) {
    for (var i = 0; i + 1 < rows.length; i++) {
      final header = rows[i];
      if (!header.contains('%') || _percent.hasMatch(header)) continue;
      if (_percentAfter.hasMatch(header)) continue;
      final rate = RegExp(
        r'^\s*(\d{1,2})[.,](\d)(?![\d])',
      ).firstMatch(rows[i + 1]);
      if (rate == null) continue;
      final p = int.parse(rate.group(1)!) * 10 + int.parse(rate.group(2)!);
      if (p < 10 || p > 300) continue;
      final values = [
        ...amounts(rows[i + 1].substring(rate.end)),
        if (i + 2 < rows.length) ...amounts(rows[i + 2]),
      ].map((m) => m.cents).toList();
      for (final net in values) {
        for (final vat in values) {
          if (net == vat || !values.contains(net + vat)) continue;
          if ((vat - _vatOfNet(net, p)).abs() <= _tolerance(Money(vat))) {
            return DetectedVat(
              permille: p,
              net: Money(net),
              vat: Money(vat),
              confidence: 90,
            );
          }
        }
      }
    }
    return null;
  }

  /// Gängige Umsatzsteuersätze der EU-Mitgliedstaaten in Promille, für
  /// Belege, die die Steuer nur als Betrag ohne Prozentsatz nennen
  /// („HERAF MOMS 137,18“). Quelle: Europäische Kommission, „VAT rates applied
  /// in the Member States of the European Union“ (Stand 2026-01-01);
  /// Rechtsgrundlage Art. 96 bis 99 MwStSystRL 2006/112/EG.
  static const euRates = [
    50, 55, 60, 70, 80, 90, 95, 100, 120, 130, 140, 150, 170, 180, 190, //
    200, 210, 220, 230, 240, 250, 255, 270,
  ];

  /// Enthaltene Steuer als Betrag neben einem Schlüsselwort, Satz aus
  /// Gesamtbetrag und Steuer zurückgerechnet.
  DetectedVat? _includedVat(List<String> rows) {
    final gross = _gross(rows);
    if (gross == null || gross.confidence < 60) return null;
    for (final row in rows) {
      final lower = row.toLowerCase();
      if (!RegExp(
        // Auch blanke Steuerzeilen mit Betrag („MwSt. € 16,50“, „VAT“,
        // „Tax“): Satz aus Brutto und Steuer (Gerätetest 2026-10-15, Apple).
        r'heraf moms|moms|inkl\.? (mwst|ust)|enthaltene|darin enthalten|incl\.? vat|included vat|'
        r'^\s*(mwst|ust|vat|tax|steuer)\b',
      ).hasMatch(lower)) {
        continue;
      }
      final a = amounts(row);
      if (a.isEmpty) continue;
      final vat = a.last.cents;
      final net = gross.value.cents - vat;
      if (vat <= 0 || net <= 0) continue;
      for (final p in euRates) {
        if ((vat - _vatOfGross(gross.value.cents, p)).abs() <=
            _tolerance(Money(vat))) {
          return DetectedVat(
            permille: p,
            net: Money(net),
            vat: Money(vat),
            confidence: 80,
          );
        }
      }
    }
    return null;
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
    r'\b\d{1,2}[./-]\d{1,2}[./-](\d{4}|\d{2})\b|\b\d{1,2}\.\d{1,2},\d{4}\b|\b\d{4}[-.]\d{2}[-.]\d{2}\b',
  );

  static const _months = {
    'jan': 1, 'feb': 2, 'mär': 3, 'maer': 3, 'mar': 3, 'apr': 4, 'mai': 5, //
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'okt': 10, 'oct': 10,
    'nov': 11, 'dez': 12, 'dec': 12,
  };

  /// Gleiches Trennzeichen, oder Punkt und Komma gemischt: ML Kit liest den
  /// zweiten Punkt auf Thermopapier oft als Komma („05.09,2026“, Korpus).
  static final _numericDate = RegExp(
    r'(?<![\d.,])(\d{1,2})([./-])(\d{1,2})(?:\2|(?<=\.\d{1,2}),)(\d{4}|\d{2})(?![\d.,]?\d)',
  );

  /// ISO und ungarisch „2026.09.03.“.
  static final _isoDate = RegExp(r'(?<!\d)(\d{4})([-.])(\d{2})\2(\d{2})(?!\d)');
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
      var score = ReceiptKeywords.any(ReceiptKeywords.date, lower) ? 92 : 75;
      if (ReceiptKeywords.any(ReceiptKeywords.notIssueDate, lower)) {
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
          int.parse(m.group(3)!),
          int.parse(m.group(4)!),
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
      if (found.isEmpty && score == 92) {
        // Jahreszahl auf Thermopapier entstellt („03.10.2ULG“, DARS-Beleg):
        // nur neben einem Datums-Schlüsselwort, Jahr aus dem Stichtag, damit
        // höchstens ein Jahr zurück; geringe Konfidenz, Nutzerin prüft.
        final m = RegExp(
          r'(?<![\d.,])(\d{1,2})\.(\d{1,2})\.2[0-9A-Za-z]{3}(?![0-9A-Za-z])',
        ).firstMatch(row);
        if (m != null && RegExp('[A-Za-z]').hasMatch(m.group(0)!)) {
          final d = int.parse(m.group(1)!);
          final mo = int.parse(m.group(2)!);
          final date = _valid(now.year, mo, d) ?? _valid(now.year - 1, mo, d);
          if (date != null && (best == null || best.confidence < 60)) {
            best = Detected(date, 60);
          }
        }
        continue;
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
    r'\btel\b|\bfax\b|www|http|@|\buid\b|\bust\b|steuer|str\.|straße\b|strasse\b|gasse\b|platz\b|weg\b|'
    r'filiale|willkommen|welcome|danke|kopie|duplikat|zweitschrift|storno|original|seite|page',
  );

  /// Bekannte Anbieter digitaler Dienste (Gebühren, Abos, App-Stores),
  /// deren Belege oft nur den Markennamen tragen (Gerätetest 2026-10-15).
  static const knownVendors = [
    'Google', 'Apple', 'Amazon', 'Microsoft', 'Meta', 'Adobe', //
    'PayPal', 'Stripe', 'Dropbox', 'Zoom', 'Spotify', 'Netflix',
  ];

  Detected<String>? _merchant(List<String> rows) {
    for (var i = 0; i < rows.length && i < 6; i++) {
      final chain = ReceiptClassifier.chainIn(rows[i], exactOnly: true);
      if (chain != null) return Detected(chain.$1, 85);
    }
    final heuristic = _merchantHeuristic(rows);
    if (heuristic != null && heuristic.confidence >= 75) return heuristic;
    // Bekannter Anbieter als eigenes Wort irgendwo auf dem Beleg; in einer
    // Kopfzeile allein stehend sicherer als im Fließtext.
    for (var i = 0; i < rows.length; i++) {
      for (final v in knownVendors) {
        final word = RegExp(
          '(?<![A-Za-z])$v(?![A-Za-z])',
          caseSensitive: false,
        );
        if (!word.hasMatch(rows[i])) continue;
        final alone = rows[i].trim().toLowerCase() == v.toLowerCase();
        return Detected(v, alone && i < 6 ? 80 : 65);
      }
    }
    return heuristic;
  }

  Detected<String>? _merchantHeuristic(List<String> rows) {
    for (var i = 0; i < rows.length && i < 6; i++) {
      final row = rows[i].trim();
      final letters = RegExp(r'[A-Za-zÄÖÜäöüß]').allMatches(row).length;
      if (letters < 3 || letters * 2 < row.length) continue;
      if (RegExp(r'^\d').hasMatch(row) || row.contains('):')) continue;
      if (_notMerchant.hasMatch(row.toLowerCase())) continue;
      final legalForm = RegExp(
        r'\b(gmbh|ag|kg|og|e\.u\.|e\.k\.|ltd|inc|llc|se|co|d\.d|d\.o\.o)\b',
        caseSensitive: false,
      ).hasMatch(row);
      // Rechtsform beendet den Namen; danach folgt oft Rauschen aus einem
      // daneben liegenden Block („… GMBH  72% sos“).
      final end = RegExp(
        r'\b(gmbh|ag|kg|og|e\.u\.|e\.k\.|ltd|inc|llc|se|d\.d\.|d\.o\.o\.)(?=\s|$)',
        caseSensitive: false,
      ).firstMatch(row);
      final name = (end == null ? row : row.substring(0, end.end)).replaceAll(
        RegExp(r'\s{2,}'),
        ' ',
      );
      return Detected(name, legalForm ? 75 : (i == 0 ? 60 : 45));
    }
    return null;
  }

  static final _vatIdPattern = RegExp(
    r'(ATU[0-9OIL]{8}|DE[0-9OIL]{9}|(?:BE|BG|CY|CZ|DK|EE|EL|ES|FI|FR|HR|HU|IE|IT|LT|LU|LV|MT|NL|PL|PT|RO|SE|SI|SK)[0-9A-Z]{8,12})',
  );

  Detected<String>? _vatId(List<String> rows) {
    final own = ownVatId == null ? null : VatIdFormat.normalize(ownVatId!);
    // Dänemark: die USt-Nummer ist „DK“ + CVR-Nummer; Belege drucken oft nur
    // „CVR: 12345678“.
    for (final row in rows) {
      final cvr = RegExp(
        r'\bCVR\b[^0-9]{0,4}(\d{2} ?\d{2} ?\d{2} ?\d{2})\b',
      ).firstMatch(row);
      if (cvr == null) continue;
      final candidate = 'DK${cvr.group(1)!.replaceAll(' ', '')}';
      if (candidate != own && VatIdFormat.check(candidate) == null) {
        return Detected(candidate, 80);
      }
    }
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
              !(RegExp(r'uid', caseSensitive: false).hasMatch(row) ||
                  _taxWord(row.toLowerCase()))) {
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

  Detected<String>? _invoiceNumber(List<String> rows) {
    final token = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/_.]*');
    final label = ReceiptKeywords.pattern(ReceiptKeywords.invoiceNumber);
    for (var i = 0; i < rows.length; i++) {
      final bare = RegExp(
        r'^\s*(rechnung|invoice|faktura|račun|racun|fattura|számla|facture|factura)\s+(\d{3,})\b',
        caseSensitive: false,
      ).firstMatch(rows[i]);
      if (bare != null) return Detected(bare.group(2)!, 75);
      final lower = rows[i].toLowerCase();
      final m = label.firstMatch(lower);
      if (m == null) continue;
      var rest = rows[i]
          .substring(m.end)
          .replaceFirst(
            RegExp(
              r'^[\s.:#°ºr]*(?:no\.?|nr\.?|št\.?|br\.?)?[\s.:#°]*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (rest.isEmpty && i + 1 < rows.length) rest = rows[i + 1].trim();
      final t = token
          .firstMatch(rest)
          ?.group(0)
          ?.replaceAll(RegExp(r'[.]$'), '');
      if (t == null || !RegExp(r'\d').hasMatch(t)) continue;
      return Detected(
        t,
        ReceiptKeywords.weightIn(ReceiptKeywords.invoiceNumber, lower),
      );
    }
    return null;
  }

  static const isoCurrencies = {
    'EUR', 'USD', 'CHF', 'GBP', 'CZK', 'HUF', 'PLN', 'SEK', 'DKK', 'NOK', //
    'JPY', 'CAD', 'AUD', 'CNY', 'TRY', 'RON', 'BGN', 'RSD', 'BAM', 'TWD',
    'HKD', 'SGD',
  };

  /// US-Merkmale für „$“ ohne Ländercode: Betrag mit „$“ davor und zwei
  /// Nachkommastellen, dazu ein englisches Monatsdatum („October 15, 2026“),
  /// eine US-Zeitzone oder englisches „Tax“/„Total“.
  static bool usSignals(List<String> rows) {
    final text = rows.join('\n');
    if (!RegExp(r'(?<![A-Z])\$\s?\d[\d,]*\.\d{2}\b').hasMatch(text)) {
      return false;
    }
    return RegExp(
      r'\b(january|february|march|april|may|june|july|august|september|'
      r'october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|'
      r'nov|dec)\.? \d{1,2}, \d{4}\b|\b[PMCE][SD]T\b|^\s*(tax|total|subtotal)\b',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(text);
  }

  Detected<String> _currency(List<String> rows) {
    final counts = <String, int>{};
    var dollar = false;
    var kronor = false;
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
      for (final _ in RegExp(r'US\$').allMatches(row)) {
        add('USD');
      }
      for (final _ in RegExp(r'NT\$').allMatches(row)) {
        add('TWD');
      }
      if (RegExp(r'(?<![A-Z])\$').hasMatch(row)) dollar = true;
      if (RegExp(
        r'\d\s?kr\b|\bkr\.?\s?\d',
        caseSensitive: false,
      ).hasMatch(row)) {
        kronor = true;
      }
      if (RegExp(r'\bS?Fr\.\s?\d').hasMatch(row)) add('CHF');
    }
    if (counts.isEmpty) {
      // „$“ allein ist mehrdeutig (USD, TWD, HKD, CAD, AUD …), „kr“ ebenso
      // (DKK, SEK, NOK): nur schwach vermuten, damit der Betrag weder als
      // Euro noch ungeprüft als Fremdwährung vorbelegt wird.
      // Ausnahme (Gerätetest 2026-10-15, Google-Beleg): „$25.00“ direkt vor
      // dem Betrag zusammen mit US-Merkmalen (englisches Monatsdatum, US-
      // Zeitzone, „Tax“/„Total“) ist ein starker Hinweis auf USD. Vorbelegt
      // als Vorschlag (Konfidenz 60), die Nutzerin bestätigt.
      if (dollar && usSignals(rows)) return const Detected('USD', 60);
      if (dollar) return const Detected('USD', 30);
      if (kronor) return const Detected('DKK', 30);
      return const Detected('EUR', 40);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Detected(sorted.first.key, counts.length == 1 ? 90 : 60);
  }
}
