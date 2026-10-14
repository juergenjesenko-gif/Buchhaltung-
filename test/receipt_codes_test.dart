// Kassen-QR (RKSV, TSE), Zahlungs-QR (EPC069-12) und Link-QR (L-27.1 bis
// L-27.3, L-27.7). Fixtures in test/fixtures/codes/ nach dem Format des
// A-SIT-Mustercodes (MachineCodeValue.java) bzw. DSFinV-K Anhang I und
// EPC069-12; die PNG-Fassungen nutzt der Emulator-Test.
import 'dart:io';

import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_code_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_codes.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    File('test/fixtures/codes/$name').readAsStringSync().trimRight();

void main() {
  group('RKSV', () {
    test('Normal 20 % und Ermäßigt-1 10 %', () {
      final code = ReceiptCode.parse(fixture('rksv_normal_ermaessigt.txt'));
      expect(code, isA<RksvCode>());
      final r = code as RksvCode;
      expect(r.registerId, 'DEMO-CASH-BOX817');
      expect(r.receiptNumber, '83810');
      expect(r.dateTime, DateTime(2026, 9, 25, 19, 20, 13));
      expect(r.amounts.map((a) => (a.permille, a.gross.cents)), [
        (200, 1200),
        (100, 550),
      ]);
      expect(r.gross, const Money(1750));
    });

    test('Tausenderpunkt und „Besonders“ ohne festen Satz', () {
      final r = ReceiptCode.parse(fixture('rksv_besonders.txt')) as RksvCode;
      expect(r.amounts.first.gross, const Money(123456));
      expect(r.amounts.last.permille, isNull);
      expect(r.amounts.last.field, 'Besonders');
    });

    test('falsche Feldzahl oder Betrag wird verworfen', () {
      expect(RksvCode.tryParse('_R1-AT1_K_1_2026-01-01T00:00:00_1,00'), isNull);
      final bad = fixture(
        'rksv_normal_ermaessigt.txt',
      ).replaceFirst('_12,00_', '_12.0_');
      expect(RksvCode.tryParse(bad), isNull);
    });
  });

  test('TSE Kassenbeleg-V1', () {
    final t = ReceiptCode.parse(fixture('tse_kassenbeleg.txt')) as TseCode;
    expect(t.registerId, '955002-00');
    expect(t.dateTime, DateTime(2026, 9, 1, 10, 0, 5));
    expect(t.amounts.map((a) => (a.permille, a.gross.cents)), [
      (190, 7533),
      (70, 799),
    ]);
  });

  test('EPC069-12 GiroCode', () {
    final e = ReceiptCode.parse(fixture('epc_girocode.txt')) as EpcCode;
    expect(e.name, 'Franz Mustermann');
    expect(e.iban, 'AT611904300234573201');
    expect(e.amount, const Money(12345));
    expect(e.reference, 'Rechnung 2026-17');
    // Falsche Prüfziffer
    expect(
      EpcCode.tryParse(
        fixture('epc_girocode.txt').replaceFirst('AT61', 'AT62'),
      ),
      isNull,
    );
  });

  test('Link-QR nur https', () {
    expect(
      ReceiptCode.parse('https://rechnung.example.at/r/123'),
      isA<LinkCode>(),
    );
    expect(ReceiptCode.parse('http://rechnung.example.at/r/123'), isNull);
    expect(ReceiptCode.parse('https://user:pw@example.at/'), isNull);
  });

  test('parseCents ohne Gleitkomma', () {
    expect(parseCents('1.234,56', decimal: ',', group: '.'), 123456);
    expect(parseCents('-3,50', decimal: ',', group: '.'), -350);
    expect(parseCents('7.99', decimal: '.'), 799);
    expect(parseCents('7,999', decimal: ','), isNull);
  });

  group('Zusammenführung', () {
    const base = ReceiptScanPrefill(
      gross: Money(1700),
      counterparty: 'SPAR',
      vatPermille: 200,
    );

    test('Kassen-QR hat Vorrang bei Betrag, Datum, Sätzen', () {
      final code = ReceiptCode.parse(fixture('rksv_normal_ermaessigt.txt'))!;
      final p = ReceiptCodePrefill.merge(
        base,
        [code],
        profile: TaxProfile.austria,
        direction: BookingDirection.expense,
      );
      expect(p.gross, const Money(1750));
      expect(p.date, DateTime(2026, 9, 25));
      expect(p.vatParts.map((v) => v.permille).toSet(), {200, 100});
      expect(p.counterparty, 'SPAR');
      expect(p.codeSource, 'Kassen-QR');
      expect(p.registerId, 'AT:DEMO-CASH-BOX817');
    });

    test('gelernter Händler schlägt Texterkennung', () {
      final code = ReceiptCode.parse(fixture('rksv_normal_ermaessigt.txt'))!;
      final p = ReceiptCodePrefill.merge(
        base,
        [code],
        profile: TaxProfile.austria,
        direction: BookingDirection.expense,
        knownMerchant: 'SPAR Filiale Hauptplatz',
      );
      expect(p.counterparty, 'SPAR Filiale Hauptplatz');
    });

    test('Besonders: Satz aus dem Text (4,9 %), sonst nicht raten', () {
      final code = ReceiptCode.parse(fixture('rksv_besonders.txt'))!;
      const ocr = ReceiptScanResult(
        currency: Detected('EUR', 90),
        vatLines: [
          DetectedVat(
            permille: 49,
            net: Money(467),
            vat: Money(23),
            confidence: 80,
          ),
        ],
      );
      final resolved = ReceiptCodePrefill.merge(
        base,
        [code],
        profile: TaxProfile.austria,
        direction: BookingDirection.expense,
        ocr: ocr,
      );
      expect(resolved.vatParts.map((v) => v.permille).toSet(), {200, 49});

      final open = ReceiptCodePrefill.merge(
        base,
        [code],
        profile: TaxProfile.austria,
        direction: BookingDirection.expense,
      );
      expect(open.vatParts, isEmpty);
      expect(open.gross, const Money(123946));
      expect(open.hints.join(), contains('4,9 % oder 19 %'));
    });

    test('Zahlungs-QR belegt Empfänger, Betrag und Notiz vor', () {
      final code = ReceiptCode.parse(fixture('epc_girocode.txt'))!;
      final p = ReceiptCodePrefill.merge(
        base,
        [code],
        profile: TaxProfile.austria,
        direction: BookingDirection.expense,
      );
      expect(p.counterparty, 'Franz Mustermann');
      expect(p.gross, const Money(12345));
      expect(p.note, contains('AT611904300234573201'));
      expect(p.note, contains('Rechnung 2026-17'));
    });
  });
}
