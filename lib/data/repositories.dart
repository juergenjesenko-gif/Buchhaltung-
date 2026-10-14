import 'package:sqflite/sqflite.dart';

import '../domain/company_profile.dart';
import '../domain/country.dart';
import '../domain/customer.dart';
import '../domain/dunning.dart';
import '../domain/invoice.dart';
import '../domain/money.dart';
import '../domain/receipt.dart';
import 'consent_repository.dart';
import 'vat_check_repository.dart';

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

  /// Aktualisiert nur die Spalten des Profils. Kein `REPLACE`: das hätte
  /// Spalten, die nicht im Formular stehen (z. B. Einstellungen der
  /// automatischen Sicherung), auf ihre Standardwerte zurückgesetzt.
  Future<void> save(CompanyProfile profile) async {
    final updated = await _db.update(
      'company_profile',
      profile.toMap(),
      where: 'id = 1',
    );
    if (updated == 0) {
      await _db.insert('company_profile', {'id': 1, ...profile.toMap()});
    }
    await AuditLog(
      _db,
    ).record(entity: 'company_profile', entityId: 1, action: 'save');
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
    bool cancelledOnly = false,
  }) async {
    // Stornierte Belege bleiben gespeichert (Aufbewahrungspflicht), zählen
    // aber nirgends mehr mit. Lesbar bleiben sie über [cancelledOnly].
    final where = <String>[
      cancelledOnly ? 'cancelled_at IS NOT NULL' : 'cancelled_at IS NULL',
    ];
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
      where: where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    final split = await splitLines();
    return [
      for (final row in rows)
        Receipt.fromMap(row, split[row['id']] ?? const []),
    ];
  }

  /// Zeilen aller Belege mit mehr als einem Steuersatz (L-2.27), je
  /// Beleg-ID in Positionsreihenfolge. Belege mit einem Satz brauchen keine
  /// Zeilen zu laden, ihr Kopf ist die Zeile.
  Future<Map<int, List<ReceiptVatLine>>> splitLines([
    DatabaseExecutor? db,
  ]) async {
    final rows = await (db ?? _db).rawQuery('''
      SELECT * FROM receipt_vat_lines
      WHERE receipt_id IN (
        SELECT receipt_id FROM receipt_vat_lines
        GROUP BY receipt_id HAVING COUNT(*) > 1
      )
      ORDER BY receipt_id, position
    ''');
    final result = <int, List<ReceiptVatLine>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['receipt_id'] as int, () => [])
          .add(ReceiptVatLine.fromMap(row));
    }
    return result;
  }

  /// Steuersatzzeilen eines Belegs; immer mindestens eine.
  Future<List<ReceiptVatLine>> vatLines(int receiptId) async {
    final rows = await _db.query(
      'receipt_vat_lines',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'position',
    );
    return rows.map(ReceiptVatLine.fromMap).toList();
  }

  /// Schreibt die Steuersatzzeilen eines Belegs neu (L-2.27). Belege mit
  /// einem Satz bekommen genau eine Zeile aus dem Kopf.
  static Future<void> writeVatLines(
    DatabaseExecutor db,
    int receiptId,
    Receipt receipt,
  ) async {
    final lines = receipt.lines;
    for (final line in lines) {
      if (!line.isConsistent) {
        throw StateError('Steuersatzzeile verletzt net + vat == gross');
      }
    }
    final header = lines.map((l) => l.gross).sum;
    if (header != receipt.gross) {
      throw StateError('Summe der Steuersätze ungleich Belegbetrag');
    }
    await db.delete(
      'receipt_vat_lines',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
    for (var i = 0; i < lines.length; i++) {
      await db.insert('receipt_vat_lines', lines[i].toMap(receiptId, i + 1));
    }
  }

  Future<Receipt?> byId(int id) async {
    final rows = await _db.query(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Receipt.fromMap(rows.first, await vatLines(id));
  }

  /// Speichert einen Beleg samt Seiten (L-2.15) und optional einem ersten
  /// Kommentar (L-2.17) in einer Transaktion.
  ///
  /// [pages] sind die relativen Bildpfade in fester Reihenfolge; `null` lässt
  /// die Seiten unverändert. Bei einem bereits gespeicherten Beleg dürfen
  /// Seiten nur **angehängt** werden – Löschen oder Umsortieren ist nur vor
  /// dem ersten Speichern möglich (GoBD Rz. 58 ff., § 131 Abs 1 Z 8 BAO).
  /// Ein stornierter Beleg ist schreibgeschützt.
  Future<int> save(
    Receipt receipt, {
    List<String>? pages,
    String? comment,
    String? scanAudit,
    bool completenessConfirmed = false,
  }) async {
    // Vollständigkeitsbestätigung (L-2.16, FA-2.14): wer neue Seiten mit
    // „Vollständig – Beleg speichern“ bucht, bestätigt damit ausdrücklich,
    // dass alle Seiten erfasst sind. Das steht wörtlich im Protokoll.
    final confirmation = completenessConfirmed
        ? ', Vollständigkeit bestätigt'
        : '';
    return _db.transaction((txn) async {
      final audit = AuditLog(_db);
      final withCover = pages == null
          ? receipt
          : pages.isEmpty
          ? receipt.copyWith(clearImage: true)
          : receipt.copyWith(imagePath: pages.first);
      final int id;
      if (receipt.id == null) {
        id = await txn.insert('receipts', withCover.toMap());
        await audit.record(
          entity: 'receipt',
          entityId: id,
          action: 'create',
          detail:
              '${receipt.description} ${receipt.gross}, '
              '${pages?.length ?? 0} Seite(n)$confirmation',
          txn: txn,
        );
      } else {
        id = receipt.id!;
        final current = await txn.query(
          'receipts',
          columns: ['cancelled_at'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (current.isNotEmpty && current.first['cancelled_at'] != null) {
          throw StateError('Ein stornierter Beleg kann nicht geändert werden');
        }
        if (pages != null) {
          final existing = await _pagePaths(txn, id);
          final keepsOrder =
              pages.length >= existing.length &&
              List.generate(
                existing.length,
                (i) => pages[i] == existing[i],
              ).every((same) => same);
          if (!keepsOrder) {
            throw StateError(
              'Seiten eines gespeicherten Belegs können nur ergänzt werden',
            );
          }
        }
        await txn.update(
          'receipts',
          withCover.toMap(),
          where: 'id = ?',
          whereArgs: [id],
        );
        await audit.record(
          entity: 'receipt',
          entityId: id,
          action: 'update',
          detail:
              '${receipt.description} ${receipt.gross}'
              '${pages == null ? '' : ', ${pages.length} Seite(n)'}'
              '$confirmation',
          txn: txn,
        );
      }
      await writeVatLines(txn, id, receipt);
      if (pages != null) await _writePages(txn, id, pages);
      // Kurs, Quelle und Überschreibung durch den Bankbetrag (L-2.26).
      final fx = fxAuditDetail(receipt);
      if (fx != null) {
        await audit.record(
          entity: 'receipt',
          entityId: id,
          action: 'fx',
          detail: fx,
          txn: txn,
        );
      }
      // Automatisch ausgelesene Werte gegenüber bestätigten (L-2.22).
      if (scanAudit != null) {
        await audit.record(
          entity: 'receipt',
          entityId: id,
          action: 'scan',
          detail: scanAudit,
          txn: txn,
        );
      }
      final text = comment?.trim() ?? '';
      if (text.isNotEmpty) await _insertComment(txn, id, text);
      return id;
    });
  }

  static Future<List<String>> _pagePaths(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'receipt_pages',
      columns: ['image_path'],
      where: 'receipt_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    return rows.map((r) => r['image_path'] as String).toList();
  }

  /// Ergänzt fehlende Seiten am Ende; vorhandene bleiben unberührt.
  static Future<void> _writePages(
    DatabaseExecutor db,
    int id,
    List<String> pages,
  ) async {
    final existing = await _pagePaths(db, id);
    final now = DateTime.now().toIso8601String();
    for (var i = existing.length; i < pages.length; i++) {
      await db.insert('receipt_pages', {
        'receipt_id': id,
        'position': i + 1,
        'image_path': pages[i],
        'created_at': now,
      });
    }
  }

  /// Alle Seiten eines Belegs in ihrer Reihenfolge.
  Future<List<ReceiptPage>> pages(int receiptId) async {
    final rows = await _db.query(
      'receipt_pages',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'position',
    );
    return rows.map(ReceiptPage.fromMap).toList();
  }

  /// Seitenzahl je Beleg, für Liste und Export.
  /// Originaldateien je Beleg für den Export (L-27.8): „Name (SHA-256 …)“.
  Future<Map<int, String>> documentSummaries() async {
    final rows = await _db.query(
      'receipt_documents',
      orderBy: 'receipt_id, id',
    );
    final result = <int, String>{};
    for (final r in rows) {
      final id = r['receipt_id'] as int;
      final entry = '${r['file_name']} (SHA-256 ${r['sha256']})';
      result[id] = result.containsKey(id) ? '${result[id]} | $entry' : entry;
    }
    return result;
  }

  /// Hängt Originaldateien an einen gespeicherten Beleg (nur Einfügen).
  Future<void> addDocuments(int receiptId, List<ReceiptDocument> docs) async {
    if (docs.isEmpty) return;
    await _db.transaction((txn) async {
      for (final d in docs) {
        await txn.insert('receipt_documents', d.toMap(receiptId));
        await txn.insert('audit_log', {
          'entity': 'receipt',
          'entity_id': receiptId,
          'action': 'document',
          'detail':
              '${d.fileName}; ${d.mime}; ${d.sizeBytes} Byte; '
              'sha256=${d.sha256}; Quelle ${d.source}',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<ReceiptDocument>> documents(int receiptId) async {
    final rows = await _db.query(
      'receipt_documents',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'id',
    );
    return [for (final r in rows) ReceiptDocument.fromMap(r)];
  }

  Future<Map<int, int>> pageCounts() async {
    final rows = await _db.rawQuery(
      'SELECT receipt_id, COUNT(*) AS n FROM receipt_pages GROUP BY receipt_id',
    );
    return {for (final r in rows) r['receipt_id'] as int: r['n'] as int};
  }

  /// Hängt einen Kommentar an – auch an gebuchte und stornierte Belege. Der
  /// Zeitstempel kommt vom System, nicht von der Nutzerin. Eine Korrektur ist
  /// ein weiterer Kommentar; Ändern und Löschen gibt es nicht (L-2.17).
  Future<ReceiptComment> addComment(int receiptId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Ein Kommentar darf nicht leer sein');
    }
    return _db.transaction((txn) => _insertComment(txn, receiptId, trimmed));
  }

  static Future<ReceiptComment> _insertComment(
    DatabaseExecutor db,
    int receiptId,
    String text,
  ) async {
    final now = DateTime.now();
    final id = await db.insert('receipt_comments', {
      'receipt_id': receiptId,
      'text': text,
      'created_at': now.toIso8601String(),
    });
    await db.insert('audit_log', {
      'entity': 'receipt',
      'entity_id': receiptId,
      'action': 'comment',
      'detail': 'Kommentar $id (${text.length} Zeichen)',
      'created_at': now.toIso8601String(),
    });
    return ReceiptComment(
      id: id,
      receiptId: receiptId,
      text: text,
      createdAt: now,
    );
  }

  /// Kommentare eines Belegs, älteste zuerst.
  Future<List<ReceiptComment>> comments(int receiptId) async {
    final rows = await _db.query(
      'receipt_comments',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
      orderBy: 'created_at, id',
    );
    return rows.map(ReceiptComment.fromMap).toList();
  }

  /// Alle Kommentare, gruppiert je Beleg – für den Export.
  Future<Map<int, List<ReceiptComment>>> allComments() async {
    final rows = await _db.query(
      'receipt_comments',
      orderBy: 'receipt_id, created_at, id',
    );
    final result = <int, List<ReceiptComment>>{};
    for (final row in rows) {
      final comment = ReceiptComment.fromMap(row);
      result.putIfAbsent(comment.receiptId, () => []).add(comment);
    }
    return result;
  }

  /// Storniert einen Beleg. Er wird nicht gelöscht: Belege unterliegen der
  /// Aufbewahrungspflicht (§ 132 BAO, § 147 AO) und dürfen nicht spurlos
  /// verschwinden (GoBD, § 131 Abs 1 Z 8 BAO). Der Beleg samt Foto bleibt
  /// erhalten, zählt aber in keiner Auswertung mehr.
  Future<void> cancel(int id) async {
    final existing = await byId(id);
    await _db.update(
      'receipts',
      {'cancelled_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND cancelled_at IS NULL',
      whereArgs: [id],
    );
    await AuditLog(_db).record(
      entity: 'receipt',
      entityId: id,
      action: 'cancel',
      detail: existing == null
          ? ''
          : '${existing.date.toIso8601String()} ${existing.gross}',
    );
  }

  /// Protokolltext einer Umrechnung, `null` bei Euro-Belegen.
  static String? fxAuditDetail(Receipt r) {
    if (!r.isForeignCurrency || r.originalGross == null) return null;
    final rate = r.fxRateMicros;
    final b = StringBuffer(
      '${r.currency} ${r.originalGross!.cents} (Hundertstel)'
      '${rate == null ? ', kein Kurs' : ' / Kurs $rate (×10^6 je EUR)'}'
      ', Quelle ${r.fxRateSource?.code ?? '-'}, Kursdatum ${r.fxRateDate ?? '-'}'
      ', umgerechnet ${r.gross}',
    );
    if (r.bankGross != null) {
      b.write(
        ', Bank ${r.bankGross} überschreibt EÜR (Differenz '
        '${r.exchangeDifference})',
      );
    }
    return b.toString();
  }

  /// Summen je Richtung für einen Zeitraum – Basis für Kassabuch und UVA.
  ///
  /// Ausgewertet wird je Steuersatzzeile (L-2.27); ein Beleg ohne Zeilen
  /// zählt mit seinem Kopf als eine Zeile.
  ///
  /// Ohne Vorsteuerabzug ([inputVatDeductible] `false`, Kleinunternehmer)
  /// ist die Umsatzsteuer auf Ausgaben Teil des Aufwands: Ausgaben zählen
  /// brutto, Vorsteuer gibt es keine (AT § 12 Abs 1 iVm § 6 Abs 1 Z 27
  /// UStG 1994; DE § 19 Abs 1 S 4 UStG, § 9b Abs 1 EStG).
  Future<PeriodTotals> totals({
    required DateTime from,
    required DateTime to,
    bool inputVatDeductible = true,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT r.direction AS direction, l.vat_permille AS vat_permille,
             SUM(l.net_cents) AS net, SUM(l.vat_cents) AS vat,
             SUM(l.gross_cents) AS gross
      FROM receipts r
      JOIN (
        SELECT receipt_id, vat_permille, net_cents, vat_cents, gross_cents
        FROM receipt_vat_lines
        UNION ALL
        SELECT id, vat_permille, net_cents, vat_cents, gross_cents
        FROM receipts
        WHERE id NOT IN (SELECT receipt_id FROM receipt_vat_lines)
      ) l ON l.receipt_id = r.id
      WHERE r.date >= ? AND r.date <= ? AND r.cancelled_at IS NULL
      GROUP BY r.direction, l.vat_permille
      ''',
      [_day(from), _day(to)],
    );
    final fx = await _db.rawQuery(
      '''
      SELECT SUM(COALESCE(bank_gross_cents, gross_cents) - gross_cents) AS fx_diff
      FROM receipts
      WHERE direction = 'expense' AND date >= ? AND date <= ?
        AND cancelled_at IS NULL
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
      } else if (inputVatDeductible) {
        expenseNet += net;
        expenseVat += vat;
        expenseGross += gross;
        expenseVatByRate[permille] =
            (expenseVatByRate[permille] ?? const Money.zero()) + vat;
      } else {
        expenseNet += gross;
        expenseGross += gross;
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
      expenseFxDifference: Money((fx.first['fx_diff'] as int?) ?? 0),
      incomeNetByRate: incomeByRate,
      inputVatByRate: expenseVatByRate,
    );
  }

  /// Umsatz eines Kalenderjahres für die Kleinunternehmergrenze.
  ///
  /// Maßgeblich ist der Umsatz, also die Einnahmenseite. Für Kleinunternehmer
  /// ist netto gleich brutto; wer regelbesteuert ist, rechnet ohnehin netto.
  /// Einnahmen eines Kalenderjahres für die Kleinunternehmergrenze; mit
  /// [includeVat] brutto, sonst netto (`TaxProfile.turnoverIncludesVat`).
  Future<Money> turnoverForYear(int year, {required bool includeVat}) async {
    final column = includeVat ? 'gross_cents' : 'net_cents';
    final rows = await _db.rawQuery(
      '''
      SELECT SUM($column) AS total FROM receipts
      WHERE direction = 'income' AND date >= ? AND date <= ?
        AND cancelled_at IS NULL
      ''',
      ['$year-01-01', '$year-12-31'],
    );
    return Money((rows.first['total'] as int?) ?? 0);
  }

  static String _day(DateTime date) => date.toIso8601String().substring(0, 10);
}

/// Umsatz eines Jahres vor Beginn der Erfassung in der App (Eröffnungswert).
class OpeningTurnoverRepository {
  const OpeningTurnoverRepository(this._db);

  final Database _db;

  /// `null`, wenn für [year] kein Eröffnungswert erfasst ist. Das ist bewusst
  /// etwas anderes als ein erfasster Wert von 0 €.
  Future<Money?> forYear(int year) async {
    final rows = await _db.query(
      'opening_turnover',
      columns: ['net_cents'],
      where: 'year = ?',
      whereArgs: [year],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Money(rows.first['net_cents'] as int);
  }

  /// Setzt den Eröffnungswert für [year]; `null` entfernt ihn.
  Future<void> save(int year, Money? amount) async {
    if (amount == null) {
      await _db.delete(
        'opening_turnover',
        where: 'year = ?',
        whereArgs: [year],
      );
    } else {
      await _db.insert('opening_turnover', {
        'year': year,
        'net_cents': amount.cents,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await AuditLog(_db).record(
      entity: 'opening_turnover',
      entityId: year,
      action: amount == null ? 'delete' : 'save',
      detail: amount?.toString() ?? '',
    );
  }
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
    this.expenseFxDifference = const Money.zero(),
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

  /// Summe der Kursdifferenzen bei Fremdwährungsbelegen: tatsächlich
  /// abgebucht minus umgerechnet (L-2.26). Positiv = Mehraufwand. Wirkt nur
  /// auf das Ergebnis der Einnahmen-Ausgaben-Rechnung, nie auf die
  /// Umsatzsteuer (Vorsteuer bleibt beim Umsatzsteuer-Kurs).
  final Money expenseFxDifference;

  /// Ausgaben brutto laut Bank (Kassabuch).
  Money get expensePaidGross => expenseGross + expenseFxDifference;

  /// Steuerpflichtige Umsätze je Steuersatz (Kennzahlen der UVA).
  final Map<int, Money> incomeNetByRate;

  /// Abziehbare Vorsteuer je Steuersatz.
  final Map<int, Money> inputVatByRate;

  /// Gewinn nach Einnahmen-Ausgaben-Rechnung (netto, ohne durchlaufende USt).
  /// Kursdifferenzen laut Bank fließen ein (L-2.26).
  Money get profit => incomeNet - expenseNet - expenseFxDifference;

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
  ///
  /// Mit [assignNumber] wird die Rechnung ausgestellt: die nächste Nummer wird
  /// in **derselben** Transaktion gezogen, damit ein Abbruch keine Lücke im
  /// Nummernkreis hinterlässt.
  ///
  /// Eine bereits gestellte Rechnung wird nie überschrieben (CLAUDE.md Regel 7);
  /// Statuswechsel laufen über [setStatus].
  Future<int> save(
    Invoice invoice, {
    String Function(int sequence)? assignNumber,
  }) async {
    return _db.transaction<int>((txn) async {
      if (invoice.id != null) {
        final rows = await txn.query(
          'invoices',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [invoice.id],
          limit: 1,
        );
        if (rows.isNotEmpty &&
            InvoiceStatus.fromName(rows.first['status'] as String).isLocked) {
          throw StateError(
            'Rechnung ${invoice.number} ist gestellt und schreibgeschützt.',
          );
        }
      }
      if (assignNumber != null) {
        final rows = await txn.query(
          'company_profile',
          columns: ['next_invoice_sequence'],
          where: 'id = 1',
          limit: 1,
        );
        final sequence = rows.isEmpty
            ? 1
            : (rows.first['next_invoice_sequence'] as int? ?? 1);
        await txn.update('company_profile', {
          'next_invoice_sequence': sequence + 1,
        }, where: 'id = 1');
        invoice = invoice.copyWith(number: assignNumber(sequence));
      }
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

  /// Setzt den Status. „Bezahlt“ läuft über [markPaid], weil dabei die
  /// Einnahme gebucht wird.
  Future<void> setStatus(int id, InvoiceStatus status) async {
    if (status == InvoiceStatus.paid) return markPaid(id, DateTime.now());
    await _db.update(
      'invoices',
      {'status': status.name},
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

  /// Markiert die Rechnung als bezahlt am [paidAt] und bucht die Einnahme
  /// (L-25.9, Gerätetest 0.3.4).
  ///
  /// Einnahmen-Ausgaben-Rechnung nach dem Zuflussprinzip (§ 19 EStG AT,
  /// § 11 EStG DE): Die Einnahme zählt am Tag des Zahlungseingangs, eine
  /// offene Rechnung zählt nicht. Je Steuersatz entsteht ein Einnahmebeleg
  /// mit `invoice_id`; der eindeutige Index (Schema 11) verhindert, dass
  /// dieselbe Rechnung zweimal gebucht wird.
  ///
  /// Mit [withSkonto] wird der Skontobetrag laut Rechnung abgezogen (L-3.24):
  /// die Einnahme je Satz mindert sich um den anteiligen Skonto (nach Brutto
  /// je Satz), damit auch die Umsatzsteuer im Zahlungsmonat (§ 16 UStG AT,
  /// § 17 UStG DE). Die Rechnung selbst bleibt unverändert (GR-8); nur der
  /// Zahlungsvorgang `skonto_taken_cents` wird vermerkt.
  ///
  /// Mit [withDunningCosts] werden Mahnkosten, Zinsen und Pauschale des
  /// letzten nicht stornierten Mahnschreibens als eine nicht
  /// umsatzsteuerbare Einnahme gebucht (L-3.30). Anrechnung nach § 1416 ABGB
  /// bzw. § 367 BGB: bei voller Zahlung sind Kosten, Zinsen und
  /// Hauptforderung gedeckt; Teilzahlungen bildet die App nicht ab.
  Future<void> markPaid(
    int id,
    DateTime paidAt, {
    bool withSkonto = false,
    bool withDunningCosts = false,
  }) async {
    var invoice = await byId(id);
    if (invoice == null) return;
    final skonto = withSkonto && invoice.hasSkonto
        ? invoice.skontoAmount
        : const Money.zero();
    invoice = invoice.copyWith(skontoTaken: skonto);
    final day = DateTime(paidAt.year, paidAt.month, paidAt.day);
    await _db.transaction((txn) async {
      await txn.update(
        'invoices',
        {
          'status': InvoiceStatus.paid.name,
          'paid_at': day.toIso8601String(),
          'skonto_taken_cents': skonto.cents,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _bookIncome(txn, invoice!, day);
      if (withDunningCosts) await _bookDunningCosts(txn, invoice!, day);
      await AuditLog(_db).record(
        entity: 'invoice',
        entityId: id,
        action: 'status',
        detail:
            'paid ${day.toIso8601String().substring(0, 10)}'
            '${skonto.isZero ? '' : ' skonto ${skonto.cents}'}',
        txn: txn,
      );
    });
  }

  /// Bucht die Einnahme für bezahlte Rechnungen nach, die noch keine haben
  /// (Rechnungen, die vor Schema 11 als bezahlt markiert wurden). Liefert
  /// die Zahl der nachgebuchten Rechnungen.
  Future<int> bookMissingPayments() async {
    final rows = await _db.rawQuery('''
      SELECT id FROM invoices
      WHERE status = 'paid'
        AND id NOT IN (SELECT invoice_id FROM receipts WHERE invoice_id IS NOT NULL)
    ''');
    var count = 0;
    for (final row in rows) {
      final invoice = await byId(row['id'] as int);
      if (invoice == null) continue;
      final day = invoice.paidAt ?? invoice.issueDate;
      await _db.transaction(
        (txn) =>
            _bookIncome(txn, invoice, DateTime(day.year, day.month, day.day)),
      );
      count++;
    }
    return count;
  }

  Future<void> _bookIncome(
    DatabaseExecutor txn,
    Invoice invoice,
    DateTime day,
  ) async {
    final existing = await txn.query(
      'receipts',
      columns: ['id'],
      where: 'invoice_id = ?',
      whereArgs: [invoice.id],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final category = await txn.query(
      'categories',
      columns: ['id'],
      where: "direction = 'income' AND name = ?",
      whereArgs: ['Umsatzerlöse'],
      limit: 1,
    );
    final customer = await txn.query(
      'customers',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [invoice.customerId],
      limit: 1,
    );
    final counterparty = customer.isEmpty
        ? ''
        : customer.first['name'] as String? ?? '';
    final booked = invoice.totals.breakdownAfterSkonto(invoice.skontoTaken);
    for (final entry in booked.entries) {
      final net = entry.value.net;
      final vat = entry.value.vat;
      if (net.isZero && vat.isZero) continue;
      final receipt = Receipt(
        date: day,
        direction: BookingDirection.income,
        description: invoice.skontoTaken.isZero
            ? 'Rechnung ${invoice.number}'
            : 'Rechnung ${invoice.number} abzgl. Skonto',
        counterparty: counterparty,
        net: net,
        vat: vat,
        gross: net + vat,
        vatPermille: entry.key,
        categoryId: category.isEmpty ? null : category.first['id'] as int?,
        documentNumber: invoice.number,
      );
      final receiptId = await txn.insert('receipts', {
        ...receipt.toMap(),
        'invoice_id': invoice.id,
      });
      await ReceiptRepository.writeVatLines(txn, receiptId, receipt);
    }
  }

  Future<void> _bookDunningCosts(
    DatabaseExecutor txn,
    Invoice invoice,
    DateTime day,
  ) async {
    final rows = await txn.query(
      'dunning_notices',
      where: 'invoice_id = ? AND cancelled_at IS NULL',
      whereArgs: [invoice.id],
      orderBy: 'level DESC',
      limit: 1,
    );
    if (rows.isEmpty) return;
    final notice = DunningNotice.fromMap(rows.first);
    if (notice.costs.isZero) return;
    final category = await txn.query(
      'categories',
      columns: ['id'],
      where: "direction = 'income' AND name = ?",
      whereArgs: ['Sonstige Einnahmen'],
      limit: 1,
    );
    final receipt = Receipt(
      date: day,
      direction: BookingDirection.income,
      description:
          'Mahnkosten und Zinsen zu Rechnung ${invoice.number} '
          '(nicht umsatzsteuerbar)',
      net: notice.costs,
      vat: const Money.zero(),
      gross: notice.costs,
      vatPermille: 0,
      categoryId: category.isEmpty ? null : category.first['id'] as int?,
      documentNumber: invoice.number,
    );
    final booked = await txn.query(
      'receipts',
      columns: ['id'],
      where: 'dunning_invoice_id = ?',
      whereArgs: [invoice.id],
      limit: 1,
    );
    if (booked.isNotEmpty) return;
    final receiptId = await txn.insert('receipts', {
      ...receipt.toMap(),
      'dunning_invoice_id': invoice.id,
    });
    await ReceiptRepository.writeVatLines(txn, receiptId, receipt);
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

/// Zahlungserinnerungen und Mahnungen (L-3.27 bis L-3.30). Nur Einfügen und
/// Stornieren; ein Trigger verhindert jede andere Änderung.
class DunningRepository {
  const DunningRepository(this._db);

  final Database _db;

  Future<List<DunningNotice>> forInvoice(int invoiceId) async {
    final rows = await _db.query(
      'dunning_notices',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'level ASC, id ASC',
    );
    return rows.map(DunningNotice.fromMap).toList();
  }

  /// Letztes nicht storniertes Schreiben je Rechnung.
  Future<Map<int, DunningNotice>> latestActive() async {
    final rows = await _db.query(
      'dunning_notices',
      where: 'cancelled_at IS NULL',
      orderBy: 'level ASC',
    );
    return {
      for (final notice in rows.map(DunningNotice.fromMap))
        notice.invoiceId: notice,
    };
  }

  Future<int> insert(DunningNotice notice) async {
    final id = await _db.insert(
      'dunning_notices',
      notice.toMap()..remove('id'),
    );
    await AuditLog(_db).record(
      entity: 'dunning',
      entityId: id,
      action: 'create',
      detail:
          '${notice.title} Rechnung ${notice.invoiceId} ${notice.total} '
          'sha256 ${notice.pdfSha256}',
    );
    return id;
  }

  Future<void> cancel(int id, String reason) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Ein Storno braucht eine Begründung.');
    }
    await _db.update(
      'dunning_notices',
      {
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancel_reason': reason.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await AuditLog(
      _db,
    ).record(entity: 'dunning', entityId: id, action: 'cancel', detail: reason);
  }
}

/// Bündel aller Repositories, damit die UI nur eine Abhängigkeit kennt.
class Repositories {
  Repositories(Database db)
    : company = CompanyRepository(db),
      categories = CategoryRepository(db),
      customers = CustomerRepository(db),
      receipts = ReceiptRepository(db),
      openingTurnover = OpeningTurnoverRepository(db),
      invoices = InvoiceRepository(db),
      dunning = DunningRepository(db),
      vatChecks = VatCheckRepository(db),
      consents = ConsentRepository(db),
      audit = AuditLog(db);

  final CompanyRepository company;
  final CategoryRepository categories;
  final CustomerRepository customers;
  final ReceiptRepository receipts;
  final OpeningTurnoverRepository openingTurnover;
  final InvoiceRepository invoices;
  final DunningRepository dunning;
  final VatCheckRepository vatChecks;
  final ConsentRepository consents;
  final AuditLog audit;
}

/// Hilfsfunktion für die Länderauswahl in Formularen.
List<Country> get supportedCountries => Country.values;
