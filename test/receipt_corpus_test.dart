// Korpustest der Belegerkennung (Stufe 1): der Parser läuft auf dem ECHTEN
// ML-Kit-Ergebnis der Belegfotos in test/fixtures/belege/ (rohe Zeilen mit
// Koordinaten aus dem CI-Job android-ocr-emulator, test/fixtures/belege/ocr/)
// und wird gegen die Sollwerte in test/fixtures/belege/erwartet.json gemessen.
//
// Ausgabe: Treffer je Feld und Trefferquote. Pflichtfelder (Brutto, Datum,
// Steuersatz) müssen für jeden Beleg mit Sollwerten stimmen, außer er steht
// mit Begründung in [_bekannteLuecken].
import 'dart:convert';
import 'dart:io';

import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_classifier.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Noch nicht gelöste Fälle: Datei → Feld → Begründung.
const _bekannteLuecken = <String, Map<String, String>>{};

// Nicht Pflicht, nur in der Quote: Währung. Taxi Taiwan: „$“ ohne chinesische Schrift (ML Kit Latin) ist nicht als TWD
// erkennbar; die App fragt die Währung nach (Hinweis in der Vorbelegung).

const _felder = [
  'brutto',
  'datum',
  'steuersatz',
  'waehrung',
  'haendler',
  'uid',
  'rechnungsnummer',
  // Weich (nur Quote): Vorschläge für Beschreibung und Kategorie.
  'beschreibung',
  'kategorie',
];

OcrDocument _ocr(Map<String, Object?> json) => OcrDocument(
  engine: json['engine'] as String? ?? '',
  engineVersion: json['engineVersion'] as String? ?? '',
  lines: [
    for (final raw in json['lines'] as List)
      OcrLine(
        (raw as Map)['text'] as String,
        left: raw['left'] as int,
        top: raw['top'] as int,
        height: raw['height'] as int,
        page: raw['page'] as int? ?? 1,
      ),
  ],
);

String _norm(String? s) =>
    (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüø]'), '');

/// Vergleicht ein Feld; `null` = kein Sollwert für dieses Feld.
bool? _treffer(
  String feld,
  Map<String, Object?> soll,
  ReceiptScanResult r, [
  ReceiptClassification? c,
]) {
  switch (feld) {
    case 'beschreibung':
      if (soll['beschreibung_enthaelt'] == null || c == null) return null;
      return (c.description ?? '').contains(
        soll['beschreibung_enthaelt'] as String,
      );
    case 'kategorie':
      if (soll['kategorie'] == null || c == null) return null;
      return c.categoryName == soll['kategorie'];
    case 'brutto':
      return r.gross?.value.cents == soll['brutto'];
    case 'datum':
      final d = r.date?.value;
      return d != null && d.toIso8601String().substring(0, 10) == soll['datum'];
    case 'steuersatz':
      final steuer = soll['steuer'] as List;
      final erwartet = steuer.isEmpty
          ? null
          : (steuer.first as Map)['promille'] as int;
      return r.dominantPermille == erwartet;
    case 'waehrung':
      return r.currency.value == soll['waehrung'];
    case 'haendler':
      if (soll['haendler'] == null) return null;
      final erkannt = _norm(r.merchant?.value);
      final s = _norm(soll['haendler'] as String);
      return erkannt.isNotEmpty && (erkannt.contains(s) || s.contains(erkannt));
    case 'uid':
      if (soll['uid'] == null) return null;
      final s = _norm(soll['uid'] as String).replaceAll(RegExp('^cvr'), '');
      return _norm(r.vatId?.value).endsWith(s);
    case 'rechnungsnummer':
      if (soll['rechnungsnummer'] == null) return null;
      return r.invoiceNumber?.value == soll['rechnungsnummer'];
  }
  return null;
}

void main() {
  final dir = Directory('test/fixtures/belege');
  final soll =
      (jsonDecode(File('${dir.path}/erwartet.json').readAsStringSync())
              as Map)['belege']
          as List;
  final parser = ReceiptTextParser(
    TaxProfile.austria,
    now: DateTime(2026, 10, 13, 18),
  );

  final ergebnisse = <String, ReceiptScanResult>{};
  final klassen = <String, ReceiptClassification>{};
  for (final beleg in soll.cast<Map<String, Object?>>()) {
    final datei = beleg['datei'] as String;
    final ocrFile = File('${dir.path}/ocr/$datei.json');
    if (!ocrFile.existsSync()) continue;
    final doc = _ocr(
      jsonDecode(ocrFile.readAsStringSync()) as Map<String, Object?>,
    );
    ergebnisse[datei] = parser.parse(doc);
    klassen[datei] = ReceiptClassifier.classify(doc.rows, ergebnisse[datei]!);
  }

  test('Trefferquote je Feld (Ausgabe)', () {
    final treffer = {for (final f in _felder) f: 0};
    final gesamt = {for (final f in _felder) f: 0};
    for (final beleg in soll.cast<Map<String, Object?>>()) {
      final r = ergebnisse[beleg['datei']];
      if (r == null) continue;
      final zeile = <String>[];
      for (final f in _felder) {
        final t = _treffer(f, beleg, r, klassen[beleg['datei']]);
        if (t == null) continue;
        gesamt[f] = gesamt[f]! + 1;
        if (t) treffer[f] = treffer[f]! + 1;
        zeile.add('$f=${t ? 'ok' : 'FEHLT'}');
        if (f == 'beschreibung') {
          zeile.add('(„${klassen[beleg['datei']]?.description}“)');
        }
      }
      // ignore: avoid_print
      print('${beleg['datei']}: ${zeile.join(' ')}');
    }
    for (final f in _felder) {
      // ignore: avoid_print
      print('Quote $f: ${treffer[f]}/${gesamt[f]}');
    }
    expect(ergebnisse, isNotEmpty);
  });

  for (final beleg in soll.cast<Map<String, Object?>>()) {
    final datei = beleg['datei'] as String;
    for (final feld in const ['brutto', 'datum', 'steuersatz']) {
      final luecke = _bekannteLuecken[datei]?[feld];
      test('$datei: $feld', () {
        final r = ergebnisse[datei];
        expect(r, isNotNull, reason: 'OCR-JSON fehlt');
        expect(
          _treffer(feld, beleg, r!),
          isTrue,
          reason:
              'erkannt: brutto=${r.gross} datum=${r.date} '
              'satz=${r.dominantPermille} währung=${r.currency}',
        );
      }, skip: luecke ?? (ergebnisse.containsKey(datei) ? false : 'kein OCR'));
    }
  }

  group('Schräg gehaltener Beleg (Gerätetest Pixel 10)', () {
    // Gleiche Zeilen wie der Mautbeleg, aber um bis zu ±3° gekippt: der
    // Betrag rechts liegt dann höher oder tiefer als die Bezeichnung links.
    final json =
        jsonDecode(
              File(
                'test/fixtures/belege/ocr/PXL_20261010_104457699.MP.jpg.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    for (final schraeg in const [-50, -30, 30, 50]) {
      test('Neigung $schraeg/1000', () {
        final doc = _ocr(json);
        final gekippt = OcrDocument(
          lines: [
            for (final l in doc.lines)
              OcrLine(
                l.text,
                left: l.left,
                top: l.top + l.left * schraeg ~/ 1000,
                height: l.height,
              ),
          ],
        );
        final r = parser.parse(gekippt);
        expect(r.gross?.value.cents, 1000);
        expect(r.dominantPermille, 200);
      });
    }
  });

  group('Vorbelegung aus dem Korpus', () {
    test('Maut AT: Brutto und 20 % werden vorbelegt', () {
      final p = ReceiptScanPrefill.from(
        ergebnisse['PXL_20261010_104457699.MP.jpg']!,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
      );
      expect(p.gross?.cents, 1000);
      expect(p.vatPermille, 200);
    });

    test('Tankbeleg DK: Fremdwährung, ausländische USt → 0 % mit Hinweis', () {
      final p = ReceiptScanPrefill.from(
        ergebnisse['PXL_20261013_043914106.jpg']!,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
      );
      expect(p.currency, 'DKK');
      expect(p.originalGross?.cents, 68588);
      expect(p.gross, isNull);
      expect(p.vatPermille, 0);
      expect(p.hints.join(), contains('nicht als Vorsteuer abziehbar'));
    });

    test('Kartenbeleg Villach ohne Steuerausweis: 0 % mit Hinweis', () {
      final p = ReceiptScanPrefill.from(
        ergebnisse['PXL_20261013_050737221.jpg']!,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
      );
      expect(p.gross?.cents, 700);
      expect(p.vatPermille, 0);
      expect(p.hints.join(), contains('Beleg ohne Steuerausweis'));
    });

    test('SPAR: 4,9 % ab 1.7.2026 vorbelegt, Händler SPAR', () {
      final r = ergebnisse['PXL_20261013_050750093.MP.jpg']!;
      final p = ReceiptScanPrefill.from(
        r,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
        classification: klassen['PXL_20261013_050750093.MP.jpg'],
      );
      expect(r.merchant?.value, 'SPAR');
      expect(p.gross?.cents, 857);
      expect(p.vatPermille, 49);
      expect(p.date, DateTime(2026, 9, 10));
      expect(p.categoryName, 'Sonstige Ausgaben');
      expect(p.description, startsWith('SPAR – Lebensmittel'));
    });

    test('DARS Slowenien: 22 % erkannt, 0 % mit Hinweis vorbelegt', () {
      final r = ergebnisse['PXL_20261014_045325288.MP.jpg']!;
      final p = ReceiptScanPrefill.from(
        r,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
      );
      expect(r.dominantPermille, 220);
      expect(r.vatLines.first.net.cents, 738);
      expect(p.gross?.cents, 900);
      expect(p.vatPermille, 0);
      expect(p.hints.join(), contains('nicht als Vorsteuer abziehbar'));
    });

    test(r'Taxi Taiwan: „$“ mehrdeutig → kein Euro-Betrag, Hinweis', () {
      final p = ReceiptScanPrefill.from(
        ergebnisse['PXL_20261013_043853962.jpg']!,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
      );
      expect(p.gross, isNull);
      expect(p.currency, 'EUR');
      expect(p.hints.join(), contains('Währung aber unklar'));
    });
  });
}
