import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/supplier_memory.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/supplier_learning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Lernen je Lieferant (FA-2.50).
void main() {
  const expense = BookingDirection.expense;

  group('Normalisierung', () {
    test('OCR-Varianten ergeben denselben Schlüssel', () {
      expect(
        SupplierLearning.normalizeName('SPAR Österreich GmbH'),
        SupplierLearning.normalizeName('spar  0sterreich'),
      );
      expect(SupplierLearning.normalizeName('Muster & Co. KG'), 'muster');
      expect(SupplierLearning.normalizeName('GmbH'), '');
    });

    test('UID geht vor Name, Richtung trennt', () {
      final keys = SupplierLearning.keys(
        expense,
        vatId: 'ATU 1234 5678',
        name: 'Hofer',
      );
      expect(keys, ['expense|UID:ATU12345678', 'expense|NAME:hofer']);
      expect(SupplierLearning.keys(expense, vatId: 'AT1'), isEmpty);
    });
  });

  group('Zusammenführen', () {
    const learned = LearnedSupplier(
      counterparty: 'SPAR Österreich',
      categoryId: 7,
      vatPermille: 100,
      currency: 'CHF',
      paymentMethod: PaymentMethod.card,
    );

    test('ohne Gelerntes bleibt der Vorschlag unverändert', () {
      const p = ReceiptScanPrefill(counterparty: 'SPARO');
      final s = SupplierLearning.merge(
        p,
        null,
        currencyConfident: true,
        direction: expense,
      );
      expect(s.prefill, same(p));
      expect(s.learnedFields, isEmpty);
    });

    test('Erkannter Satz und sichere Währung gehen vor', () {
      final s = SupplierLearning.merge(
        ReceiptScanPrefill(
          counterparty: 'SPARO',
          vatPermille: 200,
          gross: Money(1234),
          categoryName: 'Sonstige Ausgaben',
        ),
        learned,
        currencyConfident: true,
        direction: expense,
      );
      expect(s.prefill.counterparty, 'SPAR Österreich');
      expect(s.prefill.vatPermille, 200);
      expect(s.prefill.currency, 'EUR');
      expect(s.prefill.gross, Money(1234));
      expect(s.prefill.categoryName, isNull);
      expect(s.categoryId, 7);
      expect(s.paymentMethod, PaymentMethod.card);
      expect(s.learnedFields, {'counterparty', 'category', 'payment'});
    });

    test('Ohne erkannten Satz und unsichere Währung: gelernt', () {
      final s = SupplierLearning.merge(
        ReceiptScanPrefill(gross: Money(5000)),
        learned,
        currencyConfident: false,
        direction: expense,
      );
      expect(s.prefill.vatPermille, 100);
      expect(s.prefill.currency, 'CHF');
      expect(s.prefill.originalGross, Money(5000));
      expect(s.prefill.gross, isNull);
      expect(s.learnedFields, containsAll(['vat', 'currency']));
    });

    test('Einnahmen bleiben in Euro', () {
      final s = SupplierLearning.merge(
        ReceiptScanPrefill(gross: Money(5000)),
        learned,
        currencyConfident: false,
        direction: BookingDirection.income,
      );
      expect(s.prefill.currency, 'EUR');
    });
  });

  test('Speichern und Nachschlagen in Schema 20', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );
    final receipt = Receipt(
      date: DateTime(2026, 10, 1),
      direction: expense,
      description: 'Einkauf',
      counterparty: 'SPAR Österreich',
      net: Money(1000),
      vat: Money(100),
      gross: Money(1100),
      vatPermille: 100,
      categoryId: 3,
      paymentMethod: PaymentMethod.cash,
    );
    await SupplierMemory.remember(db, [
      ...SupplierLearning.keys(expense, name: receipt.counterparty),
      ...SupplierLearning.keys(expense, name: 'SPARO OSTERR'),
    ], receipt);
    final hit = await SupplierMemory.lookup(
      db,
      SupplierLearning.keys(expense, name: 'SPAR0 0STERR GmbH'),
    );
    expect(hit?.counterparty, 'SPAR Österreich');
    expect(hit?.categoryId, 3);
    expect(hit?.paymentMethod, PaymentMethod.cash);
    expect(
      await SupplierMemory.lookup(
        db,
        SupplierLearning.keys(BookingDirection.income, name: 'SPAR'),
      ),
      isNull,
    );
    await db.close();
  });
}
