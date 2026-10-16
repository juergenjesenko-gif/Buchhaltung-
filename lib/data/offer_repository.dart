import 'package:sqflite/sqflite.dart';

import '../domain/article.dart';
import '../domain/invoice.dart';
import '../domain/money.dart';
import '../domain/offer.dart';
import '../services/invoice_numbering.dart';
import 'repositories.dart' show AuditLog;

/// Artikelstamm (Lastenheft L-11, Schema 19).
class ArticleRepository {
  const ArticleRepository(this._db);

  final Database _db;

  Future<List<Article>> all() async {
    final rows = await _db.query('articles', orderBy: 'name COLLATE NOCASE');
    return rows.map(Article.fromMap).toList();
  }

  /// Ist die Artikelnummer schon vergeben (L-11.2)? Leer ist nie doppelt.
  Future<bool> numberTaken(String number, {int? exceptId}) async {
    final n = number.trim();
    if (n.isEmpty) return false;
    final rows = await _db.query(
      'articles',
      columns: ['id'],
      where: exceptId == null ? 'number = ?' : 'number = ? AND id != ?',
      whereArgs: exceptId == null ? [n] : [n, exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> save(Article article) async {
    if (article.id == null) {
      return _db.insert('articles', {
        ...article.toMap(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    await _db.update(
      'articles',
      article.toMap(),
      where: 'id = ?',
      whereArgs: [article.id],
    );
    return article.id!;
  }

  /// Löschen schadet keiner Rechnung: Positionen sind Kopien (L-11.11).
  Future<void> delete(int id) =>
      _db.delete('articles', where: 'id = ?', whereArgs: [id]);

  /// Vorschläge für eine neue Position (FA-5.45): zuerst die Artikel, dann
  /// früher verwendete Positionen aus Rechnungen und Angeboten, die kein
  /// Artikel abdeckt – je Bezeichnung die zuletzt verwendete, neueste zuerst.
  Future<List<PositionSuggestion>> suggestions({int limit = 50}) async {
    final articles = await all();
    final known = {for (final a in articles) a.name.trim().toLowerCase()};
    final rows = await _db.rawQuery('''
      SELECT description, unit, unit_price_cents, vat_permille, used_at FROM (
        SELECT i.description, i.unit, i.unit_price_cents, i.vat_permille,
               v.created_at AS used_at, i.id AS item_id
          FROM invoice_items i JOIN invoices v ON v.id = i.invoice_id
         WHERE v.cancels_invoice_id IS NULL
        UNION ALL
        SELECT i.description, i.unit, i.unit_price_cents, i.vat_permille,
               o.created_at AS used_at, i.id AS item_id
          FROM offer_items i JOIN offers o ON o.id = i.offer_id
      )
      WHERE TRIM(description) != ''
      ORDER BY used_at DESC, item_id DESC
    ''');
    final seen = <String>{};
    final used = <PositionSuggestion>[];
    for (final row in rows) {
      final description = (row['description'] as String).trim();
      final key = description.toLowerCase();
      if (known.contains(key) || !seen.add(key)) continue;
      used.add(
        PositionSuggestion(
          description: description,
          unit: row['unit'] as String? ?? 'Stk',
          unitPrice: Money(row['unit_price_cents'] as int? ?? 0),
          vatPermille: row['vat_permille'] as int? ?? 0,
        ),
      );
      if (used.length >= limit) break;
    }
    return [
      for (final a in articles)
        PositionSuggestion(
          description: a.name,
          unit: a.unit,
          unitPrice: a.unitPrice,
          vatPermille: a.vatPermille,
          article: a,
        ),
      ...used,
    ];
  }
}

/// Angebote (Lastenheft L-3.13 bis L-3.17, Schema 19). Nichts hier bucht
/// (L-3.14): weder `receipts` noch Umsatz werden berührt.
class OfferRepository {
  const OfferRepository(this._db);

  final Database _db;

  Future<List<Offer>> all() async {
    final rows = await _db.query('offers', orderBy: 'issue_date DESC, id DESC');
    return [
      for (final row in rows)
        Offer.fromMap(row, await _itemsFor(row['id'] as int)),
    ];
  }

  Future<Offer?> byId(int id) async {
    final rows = await _db.query('offers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Offer.fromMap(rows.first, await _itemsFor(id));
  }

  Future<List<InvoiceItem>> _itemsFor(int offerId) async {
    final rows = await _db.query(
      'offer_items',
      where: 'offer_id = ?',
      whereArgs: [offerId],
      orderBy: 'position ASC',
    );
    return rows.map(InvoiceItem.fromMap).toList();
  }

  /// Speichert ein Angebot samt Positionen. Ein neues Angebot zieht in
  /// derselben Transaktion die nächste Nummer seines Jahres (L-3.13).
  /// Angenommene Angebote sind schreibgeschützt.
  Future<int> save(Offer offer) => _db.transaction<int>((txn) async {
    final int id;
    if (offer.id == null) {
      final year = offer.issueDate.year;
      final rows = await txn.rawQuery(
        'SELECT MAX(sequence) AS s FROM offers WHERE year = ?',
        [year],
      );
      final sequence = ((rows.first['s'] as int?) ?? 0) + 1;
      offer = offer.copyWith(
        number: InvoiceNumbering.format(
          pattern: OfferPolicy.numberPattern,
          sequence: sequence,
          date: offer.issueDate,
        ),
      );
      id = await txn.insert('offers', {
        ...offer.toMap(),
        'year': year,
        'sequence': sequence,
      });
    } else {
      id = offer.id!;
      final rows = await txn.query(
        'offers',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty &&
          OfferStatus.fromName(rows.first['status'] as String?) ==
              OfferStatus.accepted) {
        throw StateError('Angebot ${offer.number} ist angenommen.');
      }
      final map = offer.toMap()
        ..remove('number')
        ..remove('created_at');
      await txn.update('offers', map, where: 'id = ?', whereArgs: [id]);
      await txn.delete('offer_items', where: 'offer_id = ?', whereArgs: [id]);
    }
    for (var i = 0; i < offer.items.length; i++) {
      final item = offer.items[i].copyWith(position: i + 1).toMap()
        ..remove('id')
        ..remove('invoice_id')
        ..['offer_id'] = id;
      await txn.insert('offer_items', item);
    }
    await AuditLog(_db).record(
      entity: 'offer',
      entityId: id,
      action: offer.id == null ? 'create' : 'update',
      detail: offer.number,
      txn: txn,
    );
    return id;
  });

  /// Gesendet, abgelehnt oder zurück auf offen. „Angenommen“ setzt nur
  /// [convertToInvoice].
  Future<void> setStatus(int id, OfferStatus status) async {
    assert(status != OfferStatus.accepted && status != OfferStatus.expired);
    await _db.update(
      'offers',
      {'status': status.name},
      where: "id = ? AND status != 'accepted'",
      whereArgs: [id],
    );
  }

  /// Löscht ein nicht angenommenes Angebot.
  Future<bool> delete(int id) async {
    final count = await _db.delete(
      'offers',
      where: "id = ? AND status != 'accepted'",
      whereArgs: [id],
    );
    return count > 0;
  }

  /// Wandelt das Angebot mit einem Tipp in einen **Rechnungsentwurf** um
  /// (L-3.15): Kunde und Positionen werden kopiert und bleiben vor dem
  /// Ausstellen änderbar. Das Angebot wird angenommen und schreibgeschützt.
  /// Gibt die ID des Entwurfs zurück; ein zweiter Aufruf liefert denselben.
  Future<int> convertToInvoice(
    int offerId, {
    required DateTime now,
    required int paymentTermDays,
    required bool isSmallBusiness,
  }) => _db.transaction<int>((txn) async {
    final rows = await txn.query(
      'offers',
      where: 'id = ?',
      whereArgs: [offerId],
    );
    if (rows.isEmpty) throw StateError('Angebot $offerId fehlt.');
    final existing = rows.first['invoice_id'] as int?;
    if (existing != null) return existing;
    final itemRows = await txn.query(
      'offer_items',
      where: 'offer_id = ?',
      whereArgs: [offerId],
      orderBy: 'position ASC',
    );
    final offer = Offer.fromMap(
      rows.first,
      itemRows.map(InvoiceItem.fromMap).toList(),
    );
    final today = DateTime(now.year, now.month, now.day);
    final invoice = Invoice(
      number: 'ENTWURF-${now.microsecondsSinceEpoch}',
      issueDate: today,
      deliveryDate: today,
      dueDate: today.add(Duration(days: paymentTermDays)),
      customerId: offer.customerId,
      items: offer.items,
      isSmallBusiness: isSmallBusiness,
      notes: offer.notes,
    );
    final invoiceId = await txn.insert('invoices', invoice.toMap());
    for (var i = 0; i < offer.items.length; i++) {
      final item = offer.items[i].copyWith(
        invoiceId: invoiceId,
        position: i + 1,
      );
      await txn.insert('invoice_items', item.toMap()..remove('id'));
    }
    await txn.update(
      'offers',
      {'status': OfferStatus.accepted.name, 'invoice_id': invoiceId},
      where: 'id = ?',
      whereArgs: [offerId],
    );
    await AuditLog(_db).record(
      entity: 'offer',
      entityId: offerId,
      action: 'convert',
      detail: '${offer.number} -> Rechnungsentwurf $invoiceId',
      txn: txn,
    );
    return invoiceId;
  });
}
