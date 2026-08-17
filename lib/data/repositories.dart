import 'package:sqflite/sqflite.dart';

import '../domain/company_profile.dart';
import '../domain/country.dart';
import '../domain/customer.dart';
import '../domain/invoice.dart';
import '../domain/money.dart';
import '../domain/receipt.dart';

/// Schreibt Änderungen an buchungsrelevanten Daten mit. Löschen und Ändern
/// bleiben in der App möglich, hinterlassen aber eine Spur.
class AuditLog {
  const AuditLog(this._db);

  final Database _db;

  Future<void> record({
    required String entity,
    required String action,
    int? entityId,
    String detail = '',
    DatabaseExecutor? txn,
  }) async {
    await (txn ?? _db).insert('audit_log', {
      'entity': entity,
      'entity_id': entityId,
      'action': action,
      'detail': detail,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

class CompanyRepository {
  const CompanyRepository(this._db);

  final Database _db;

  /// Gibt `null` zurück, solange das Onboarding nicht abgeschlossen ist.
  Future<CompanyProfile?> load() async {
    final rows = await _db.query('company_profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return CompanyProfile.fromMap(rows.first);
  }

  Future<void> save(CompanyProfile profile) async {
    await _db.insert(
      'company_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await AuditLog(
      _db,
    ).record(entity: 'company_profile', entityId: 1, action: 'save');
  }

  /// Reserviert die nächste Rechnungsnummer und erhöht den Zähler atomar.
  /// Läuft in einer Transaktion, damit zwei gleichzeitige Ausstellungen nicht
  /// dieselbe Nummer bekommen.
  Future<int> reserveNextInvoiceSequence() async {
    return _db.transaction<int>((txn) async {
      final rows = await txn.query(
        'company_profile',
        columns: ['next_invoice_sequence'],
        where: 'id = 1',
        limit: 1,
      );
      final current = rows.isEmpty
          ? 1
          : (rows.first['next_invoice_sequence'] as int? ?? 1);
      await txn.update('company_profile', {
        'next_invoice_sequence': current + 1,
      }, where: 'id = 1');
      return current;
    });
  }
}

class CategoryRepository {
  const CategoryRepository(this._db);

  final Database _db;

  Future<List<ExpenseCategory>> all() async {
    final rows = await _db.query(
      'categories',
      orderBy: 'direction DESC, name ASC',
    );
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  Future<List<ExpenseCategory>> byDirection(BookingDirection direction) async {
    final rows = await _db.query(
      'categories',
      where: 'direction = ?',
      whereArgs: [direction.name],
      orderBy: 'name ASC',
    );
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  Future<int> insert(ExpenseCategory category) =>
      _db.insert('categories', category.toMap());

  Future<void> delete(int id) async {
    await _db.delete(
      'categories',
      where: 'id = ? AND is_system = 0',
      whereArgs: [id],
    );
  }
}

class CustomerRepository {
  const CustomerRepository(this._db);

  final Database _db;

  Future<List<Customer>> all() async {
    final rows = await _db.query(
      'customers',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> byId(int id) async {
    final rows = await _db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<int> save(Customer customer) async {
    if (customer.id == null) {
      return _db.insert('customers', customer.toMap());
    }
    await _db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    return customer.id!;
  }

  /// Löscht einen Kunden. Schlägt fehl, wenn noch Rechnungen daran hängen –
  /// Rechnungen dürfen ihren Empfänger nicht verlieren.
  Future<bool> delete(int id) async {
    final invoices = await _db.query(
      'invoices',
      columns: ['id'],
      where: 'customer_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (invoices.isNotEmpty) return false;
    await _db.delete('customers', where: 'id = ?', whereArgs: [id]);
    return true;
  }
}

class ReceiptRepository {
  const ReceiptRepository(this._db);

  final Database _db;

  Future<List<Receipt>> query({
    DateTime? from,
    DateTime? to,
    BookingDirection? direction,
    String? search,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (from != null) {
      where.add('date >= ?');
      args.add(_day(from));
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(_day(to));
    }
    if (direction != null) {
      where.add('direction = ?');
      args.add(direction.name);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(description LIKE ? OR counterparty LIKE ? OR note LIKE ?)');
      final pattern = '%${search.trim()}%';
      args.addAll([pattern, pattern, pattern]);
    }

    final rows = await _db.query(
      'receipts',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map(Receipt.fromMap).toList();
  }

  Future<Receipt?> byId(int id) async {
    final rows = await _db.query(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Receipt.fromMap(rows.first);
  }

  Future<int> save(Receipt receipt) async {
    if (receipt.id == null) {
      final id = await _db.insert('receipts', receipt.toMap());
      await AuditLog(_db).record(
        entity: 'receipt',
        entityId: id,
        action: 'create',
        detail: '${receipt.description} ${receipt.gross}',
      );
      return id;
    }
    await _db.update(
      'receipts',
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
    await AuditLog(_db).record(
      entity: 'receipt',
      entityId: receipt.id,
      action: 'update',
      detail: '${receipt.description} ${receipt.gross}',
    );
    return receipt.id!;
  }

  Future<void> delete(int id) async {
    final existing = await byId(id);
    await _db.delete('receipts', where: 'id = ?', whereArgs: [id]);
    await AuditLog(_db).record(
      entity: 'receipt',
      entityId: id,
      action: 'delete',
      detail: existing == null
          ? ''
          : '${existing.date.toIso8601String()} ${existing.gross}',
    );
  }

  /// Summen je Richtung für einen Zeitraum – Basis für Kassabuch und UVA.
  Future<PeriodTotals> totals({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT direction, vat_permille,
             SUM(net_cents) AS net, SUM(vat_cents) AS vat, SUM(gross_cents) AS gross
      FROM receipts
      WHERE date >= ? AND date <= ?
      GROUP BY direction, vat_permille
      ''',
      [_day(from), _day(to)],
    );

    var incomeNet = const Money.zero();
    var incomeVat = const Money.zero();
    var incomeGross = const Money.zero();
    var expenseNet = const Money.zero();
    var expenseVat = const Money.zero();
    var expenseGross = const Money.zero();
    final incomeByRate = <int, Money>{};
    final expenseVatByRate = <int, Money>{};

    for (final row in rows) {
      final isIncome = row['direction'] == 'income';
      final permille = row['vat_permille'] as int? ?? 0;
      final net = Money((row['net'] as int?) ?? 0);
      final vat = Money((row['vat'] as int?) ?? 0);
      final gross = Money((row['gross'] as int?) ?? 0);

      if (isIncome) {
        incomeNet += net;
        incomeVat += vat;
        incomeGross += gross;
        incomeByRate[permille] =
            (incomeByRate[permille] ?? const Money.zero()) + net;
      } else {
        expenseNet += net;
        expenseVat += vat;
        expenseGross += gross;
        expenseVatByRate[permille] =
            (expenseVatByRate[permille] ?? const Money.zero()) + vat;
      }
    }

    return PeriodTotals(
      from: from,
      to: to,
      incomeNet: incomeNet,
      incomeVat: incomeVat,
      incomeGross: incomeGross,
      expenseNet: expenseNet,
      expenseVat: expenseVat,
      expenseGross: expenseGross,
      incomeNetByRate: incomeByRate,
      inputVatByRate: expenseVatByRate,
    );
  }

  /// Umsatz eines Kalenderjahres für die Kleinunternehmergrenze.
  ///
  /// Maßgeblich ist der Umsatz, also die Einnahmenseite. Für Kleinunternehmer
  /// ist netto gleich brutto; wer regelbesteuert ist, rechnet ohnehin netto.
  Future<Money> turnoverForYear(int year) async {
    final rows = await _db.rawQuery(
      '''
      SELECT SUM(net_cents) AS total FROM receipts
      WHERE direction = 'income' AND date >= ? AND date <= ?
      ''',
      ['$year-01-01', '$year-12-31'],
    );
    return Money((rows.first['total'] as int?) ?? 0);
  }

  static String _day(DateTime date) => date.toIso8601String().substring(0, 10);
}

/// Aggregierte Zahlen für einen Zeitraum.
class PeriodTotals {
  const PeriodTotals({
    required this.from,
    required this.to,
    required this.incomeNet,
    required this.incomeVat,
    required this.incomeGross,
    required this.expenseNet,
    required this.expenseVat,
    required this.expenseGross,
    required this.incomeNetByRate,
    required this.inputVatByRate,
  });

  final DateTime from;
  final DateTime to;

  final Money incomeNet;
  final Money incomeVat;
  final Money incomeGross;
  final Money expenseNet;
  final Money expenseVat;
  final Money expenseGross;

  /// Steuerpflichtige Umsätze je Steuersatz (Kennzahlen der UVA).
  final Map<int, Money> incomeNetByRate;

  /// Abziehbare Vorsteuer je Steuersatz.
  final Map<int, Money> inputVatByRate;

  /// Gewinn nach Einnahmen-Ausgaben-Rechnung (netto, ohne durchlaufende USt).
  Money get profit => incomeNet - expenseNet;

  /// Zahllast bzw. Guthaben gegenüber dem Finanzamt.
  Money get vatPayable => incomeVat - expenseVat;

  bool get isEmpty => incomeGross.isZero && expenseGross.isZero;
}

class InvoiceRepository {
  const InvoiceRepository(this._db);

  final Database _db;

  Future<List<Invoice>> all({InvoiceStatus? status}) async {
    final rows = await _db.query(
      'invoices',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: 'issue_date DESC, id DESC',
    );
    final invoices = <Invoice>[];
    for (final row in rows) {
      invoices.add(Invoice.fromMap(row, await _itemsFor(row['id'] as int)));
    }
    return invoices;
  }

  Future<Invoice?> byId(int id) async {
    final rows = await _db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Invoice.fromMap(rows.first, await _itemsFor(id));
  }

  Future<List<InvoiceItem>> _itemsFor(int invoiceId) async {
    final rows = await _db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'position ASC',
    );
    return rows.map(InvoiceItem.fromMap).toList();
  }

  /// Speichert Rechnung samt Positionen in einer Transaktion. Positionen werden
  /// ersetzt, nicht gemergt – das hält die Positionsnummern lückenlos.
  Future<int> save(Invoice invoice) async {
    return _db.transaction<int>((txn) async {
      final int invoiceId;
      if (invoice.id == null) {
        invoiceId = await txn.insert('invoices', invoice.toMap());
      } else {
        invoiceId = invoice.id!;
        await txn.update(
          'invoices',
          invoice.toMap(),
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
        await txn.delete(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );
      }

      for (var i = 0; i < invoice.items.length; i++) {
        final item = invoice.items[i].copyWith(
          invoiceId: invoiceId,
          position: i + 1,
        );
        await txn.insert('invoice_items', item.toMap()..remove('id'));
      }

      await AuditLog(_db).record(
        entity: 'invoice',
        entityId: invoiceId,
        action: invoice.id == null ? 'create' : 'update',
        detail: '${invoice.number} ${invoice.grossTotal}',
        txn: txn,
      );
      return invoiceId;
    });
  }

  /// Entwürfe dürfen gelöscht werden, gestellte Rechnungen nicht – dafür gibt
  /// es die Stornierung.
  Future<bool> deleteDraft(int id) async {
    final invoice = await byId(id);
    if (invoice == null || invoice.status.isLocked) return false;
    await _db.delete('invoices', where: 'id = ?', whereArgs: [id]);
    await AuditLog(
      _db,
    ).record(entity: 'invoice', entityId: id, action: 'delete_draft');
    return true;
  }

  Future<void> setStatus(int id, InvoiceStatus status) async {
    await _db.update(
      'invoices',
      {
        'status': status.name,
        if (status == InvoiceStatus.paid)
          'paid_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await AuditLog(_db).record(
      entity: 'invoice',
      entityId: id,
      action: 'status',
      detail: status.name,
    );
  }

  Future<bool> numberExists(String number, {int? exceptId}) async {
    final rows = await _db.query(
      'invoices',
      columns: ['id'],
      where: exceptId == null ? 'number = ?' : 'number = ? AND id != ?',
      whereArgs: exceptId == null ? [number] : [number, exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}

/// Bündel aller Repositories, damit die UI nur eine Abhängigkeit kennt.
class Repositories {
  Repositories(Database db)
    : company = CompanyRepository(db),
      categories = CategoryRepository(db),
      customers = CustomerRepository(db),
      receipts = ReceiptRepository(db),
      invoices = InvoiceRepository(db),
      audit = AuditLog(db);

  final CompanyRepository company;
  final CategoryRepository categories;
  final CustomerRepository customers;
  final ReceiptRepository receipts;
  final InvoiceRepository invoices;
  final AuditLog audit;
}

/// Hilfsfunktion für die Länderauswahl in Formularen.
List<Country> get supportedCountries => Country.values;
