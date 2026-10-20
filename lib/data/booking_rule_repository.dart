import 'package:sqflite/sqflite.dart';

import '../domain/booking_rule.dart';
import '../domain/country.dart';
import '../domain/money.dart';
import '../services/booking_rule_split.dart';
import '../services/reports/booking_rule_report.dart';

/// Buchungsregeln (FA-20.x): Regeln, Anhänge, Verlauf, Ausnahmen und die
/// Auswertung eines Zeitraums.
class BookingRuleRepository {
  const BookingRuleRepository(this._db);

  final Database _db;

  Future<List<BookingRule>> all() async {
    final rows = await _db.query('booking_rules', orderBy: 'id');
    return rows.map(BookingRule.fromMap).toList();
  }

  Future<BookingRule?> byId(int id) async {
    final rows = await _db.query(
      'booking_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : BookingRule.fromMap(rows.first);
  }

  /// Legt an bzw. ändert; jede Änderung schreibt einen Verlaufseintrag mit
  /// den geänderten Angaben.
  Future<BookingRule> save(BookingRule rule) async {
    final errors = rule.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.first);
    final now = DateTime.now().toIso8601String();
    return _db.transaction((txn) async {
      if (rule.id == null) {
        final id = await txn.insert('booking_rules', {
          ...rule.toMap(),
          'created_at': now,
          'updated_at': now,
        });
        await _log(txn, id, 'Angelegt: ${describe(rule)}', now);
        return rule.copyWith(id: id);
      }
      final before = await txn.query(
        'booking_rules',
        where: 'id = ?',
        whereArgs: [rule.id],
      );
      final old = before.isEmpty ? null : BookingRule.fromMap(before.first);
      await txn.update(
        'booking_rules',
        {...rule.toMap(), 'updated_at': now},
        where: 'id = ?',
        whereArgs: [rule.id],
      );
      final change = old == null ? describe(rule) : _diff(old, rule);
      if (change.isNotEmpty) {
        await _log(txn, rule.id!, 'Geändert: $change', now);
      }
      return rule;
    });
  }

  static String describe(BookingRule r) => [
    r.name,
    '${formatPermille(r.businessPermille)} betrieblich',
    'Grundlage ${r.basis.label}',
    'ab ${_d(r.validFrom)}${r.validTo == null ? '' : ' bis ${_d(r.validTo!)}'}',
  ].join(', ');

  static String _diff(BookingRule a, BookingRule b) => [
    if (a.name != b.name) 'Name „${a.name}“ → „${b.name}“',
    if (a.businessPermille != b.businessPermille)
      'Anteil ${formatPermille(a.businessPermille)} → '
          '${formatPermille(b.businessPermille)}',
    if (a.basis != b.basis) 'Grundlage ${a.basis.label} → ${b.basis.label}',
    if (a.basisPartMilli != b.basisPartMilli ||
        a.basisTotalMilli != b.basisTotalMilli)
      'Zahlen geändert',
    if (a.validFrom != b.validFrom) 'gültig ab ${_d(b.validFrom)}',
    if (a.validTo != b.validTo)
      b.validTo == null ? 'unbefristet' : 'gültig bis ${_d(b.validTo!)}',
    if (a.categoryIds.length != b.categoryIds.length ||
        !a.categoryIds.containsAll(b.categoryIds) ||
        a.supplier != b.supplier ||
        a.registration != b.registration ||
        a.registrationId != b.registrationId)
      'Geltungsbereich geändert',
    if (a.comment != b.comment) 'Begründung geändert',
  ].join('; ');

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static Future<void> _log(
    DatabaseExecutor db,
    int ruleId,
    String text,
    String at,
  ) => db.insert('booking_rule_log', {
    'rule_id': ruleId,
    'text': text,
    'created_at': at,
  });

  Future<List<BookingRuleLogEntry>> log(int ruleId) async {
    final rows = await _db.query(
      'booking_rule_log',
      where: 'rule_id = ?',
      whereArgs: [ruleId],
      orderBy: 'created_at, id',
    );
    return rows.map(BookingRuleLogEntry.fromMap).toList();
  }

  Future<BookingRuleAttachment> addAttachment({
    required int ruleId,
    required String filePath,
    required String fileName,
    String note = '',
  }) async {
    final now = DateTime.now();
    return _db.transaction((txn) async {
      final id = await txn.insert('booking_rule_attachments', {
        'rule_id': ruleId,
        'file_path': filePath,
        'file_name': fileName,
        'note': note.trim(),
        'created_at': now.toIso8601String(),
      });
      await _log(
        txn,
        ruleId,
        'Anhang: $fileName${note.trim().isEmpty ? '' : ' – ${note.trim()}'}',
        now.toIso8601String(),
      );
      return BookingRuleAttachment(
        id: id,
        ruleId: ruleId,
        filePath: filePath,
        fileName: fileName,
        note: note.trim(),
        createdAt: now,
      );
    });
  }

  Future<List<BookingRuleAttachment>> attachments(int ruleId) async {
    final rows = await _db.query(
      'booking_rule_attachments',
      where: 'rule_id = ?',
      whereArgs: [ruleId],
      orderBy: 'created_at, id',
    );
    return rows.map(BookingRuleAttachment.fromMap).toList();
  }

  /// Regel-IDs, von denen eine Buchung ausgenommen ist.
  Future<Set<int>> exclusionsFor(int receiptId) async {
    final rows = await _db.query(
      'booking_rule_exclusions',
      columns: ['rule_id'],
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
    return {for (final r in rows) r['rule_id'] as int};
  }

  /// Nimmt eine Buchung von einer Regel aus bzw. wieder auf; beides steht
  /// im Verlauf der Regel.
  Future<void> setExcluded(int ruleId, int receiptId, bool excluded) async {
    final now = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      if (excluded) {
        await txn.insert('booking_rule_exclusions', {
          'rule_id': ruleId,
          'receipt_id': receiptId,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else {
        await txn.delete(
          'booking_rule_exclusions',
          where: 'rule_id = ? AND receipt_id = ?',
          whereArgs: [ruleId, receiptId],
        );
      }
      await _log(
        txn,
        ruleId,
        excluded
            ? 'Buchung $receiptId ausgenommen'
            : 'Buchung $receiptId wieder einbezogen',
        now,
      );
    });
  }

  /// Wertet alle Regeln für die Ausgaben eines Zeitraums aus (FA-20.3).
  /// [where] grenzt die Belege ein (Alias `r`, z. B. Steuerland).
  Future<BookingRuleEvaluation> evaluate({
    required DateTime from,
    required DateTime to,
    required bool inputVatDeductible,
    required MixedUseRules rules,
    String where = '1 = 1',
  }) async {
    final all = await this.all();
    final result = BookingRuleEvaluation({
      for (final r in all) r.id!: BookingRuleSums(r),
    });
    if (all.isEmpty) return result;
    final receipts = await _db.rawQuery(
      '''
      SELECT r.id AS id, r.date AS date, r.category_id AS category_id,
             r.counterparty AS counterparty,
             r.tax_registration_id AS reg, r.vat_permille AS vp,
             r.net_cents AS net, r.vat_cents AS vat, r.gross_cents AS gross
      FROM receipts r
      WHERE r.direction = 'expense' AND r.cancelled_at IS NULL
        AND r.date >= ? AND r.date <= ? AND $where
        AND r.id NOT IN (SELECT receipt_id FROM fixed_assets
                         WHERE receipt_id IS NOT NULL)
      ''',
      [_day(from), _day(to)],
    );
    if (receipts.isEmpty) return result;
    final lineRows = await _db.rawQuery(
      '''
      SELECT l.receipt_id AS id, l.vat_permille AS vp, l.net_cents AS net,
             l.vat_cents AS vat, l.gross_cents AS gross
      FROM receipt_vat_lines l JOIN receipts r ON r.id = l.receipt_id
      WHERE r.direction = 'expense' AND r.date >= ? AND r.date <= ?
      ''',
      [_day(from), _day(to)],
    );
    final lines = <int, List<VatLineAmounts>>{};
    for (final l in lineRows) {
      lines.putIfAbsent(l['id'] as int, () => []).add((
        permille: l['vp'] as int? ?? 0,
        net: Money(l['net'] as int? ?? 0),
        vat: Money(l['vat'] as int? ?? 0),
        gross: Money(l['gross'] as int? ?? 0),
      ));
    }
    final exclusions = <int, Set<int>>{};
    for (final e in await _db.query('booking_rule_exclusions')) {
      exclusions
          .putIfAbsent(e['receipt_id'] as int, () => {})
          .add(e['rule_id'] as int);
    }
    for (final row in receipts) {
      final id = row['id'] as int;
      final facts = BookingFacts(
        date: DateTime.parse(row['date'] as String),
        isExpense: true,
        categoryId: row['category_id'] as int?,
        counterparty: row['counterparty'] as String? ?? '',
        taxRegistrationId: row['reg'] as int?,
      );
      final excluded = exclusions[id] ?? const <int>{};
      final rule = matchingRule(all, facts, excludedRuleIds: excluded);
      for (final x in excluded) {
        final ruleX = result.byRule[x];
        if (ruleX != null && ruleX.rule.matches(facts)) ruleX.excludedCount++;
      }
      if (rule == null) continue;
      final split = BookingRuleSplit.of(
        lines:
            lines[id] ??
            [
              (
                permille: row['vp'] as int? ?? 0,
                net: Money(row['net'] as int? ?? 0),
                vat: Money(row['vat'] as int? ?? 0),
                gross: Money(row['gross'] as int? ?? 0),
              ),
            ],
        businessPermille: rule.businessPermille,
        inputVatDeductible: inputVatDeductible,
        rules: rules,
      );
      result.byRule[rule.id!]!.add(split);
      result.privatePart += split.privatePart;
      result.vatAsExpense += split.vatAsExpense;
      for (final e in split.inputVatRemovedByRate.entries) {
        result.inputVatRemovedByRate[e.key] =
            (result.inputVatRemovedByRate[e.key] ?? const Money.zero()) +
            e.value;
      }
    }
    return result;
  }

  /// Einträge für Berichte und Paket (FA-20.5): Regeln, die im Zeitraum
  /// Buchungen betreffen, mit Anhängen.
  Future<List<BookingRuleReportEntry>> report({
    required DateTime from,
    required DateTime to,
    required bool inputVatDeductible,
    required MixedUseRules rules,
    required String Function(int categoryId) categoryName,
  }) async {
    final eval = await evaluate(
      from: from,
      to: to,
      inputVatDeductible: inputVatDeductible,
      rules: rules,
    );
    return [
      for (final s in eval.used)
        BookingRuleReportEntry(
          sums: s,
          scopeLabel: scopeLabel(s.rule, categoryName),
          attachments: await attachments(s.rule.id!),
        ),
    ];
  }

  /// Geltungsbereich in Worten.
  static String scopeLabel(
    BookingRule r,
    String Function(int categoryId) categoryName,
  ) => [
    if (r.categoryIds.isNotEmpty)
      'Kategorie ${(r.categoryIds.toList()..sort()).map(categoryName).join(', ')}',
    if (r.supplier.trim().isNotEmpty) 'Lieferant „${r.supplier.trim()}“',
    switch (r.registration) {
      BookingRuleRegistration.all => 'alle Steuerländer',
      BookingRuleRegistration.home => 'nur Heimatland',
      BookingRuleRegistration.one => 'nur Registrierung ${r.registrationId}',
    },
  ].join(', ');

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}

/// Ergebnis der Auswertung eines Zeitraums.
class BookingRuleEvaluation {
  BookingRuleEvaluation(this.byRule);

  final Map<int, BookingRuleSums> byRule;
  Money privatePart = const Money.zero();
  Money vatAsExpense = const Money.zero();
  final Map<int, Money> inputVatRemovedByRate = {};

  Money get inputVatRemoved =>
      inputVatRemovedByRate.values.fold(const Money.zero(), (a, b) => a + b);

  /// Regeln, die im Zeitraum mindestens eine Buchung betreffen oder gelten.
  List<BookingRuleSums> get used => [
    for (final s in byRule.values)
      if (s.count > 0 || s.excludedCount > 0) s,
  ];
}
