import 'money.dart';

/// Richtung einer Buchung. Bewusst nur zwei Werte – eine Einnahmen-Ausgaben-
/// Rechnung kennt nicht mehr.
enum BookingDirection {
  income('Einnahme'),
  expense('Ausgabe');

  const BookingDirection(this.label);
  final String label;

  int get sign => this == BookingDirection.income ? 1 : -1;
}

enum PaymentMethod {
  cash('Bar'),
  bank('Bank / Überweisung'),
  card('Karte'),
  other('Sonstiges');

  const PaymentMethod(this.label);
  final String label;

  static PaymentMethod fromName(String? name) => PaymentMethod.values
      .firstWhere((m) => m.name == name, orElse: () => PaymentMethod.bank);
}

/// Ein erfasster Beleg – Ausgangspunkt jeder Buchung in dieser App.
class Receipt {
  const Receipt({
    this.id,
    required this.date,
    required this.direction,
    required this.description,
    required this.net,
    required this.vat,
    required this.gross,
    required this.vatPermille,
    this.counterparty = '',
    this.categoryId,
    this.paymentMethod = PaymentMethod.bank,
    this.imagePath,
    this.note = '',
    this.createdAt,
    this.updatedAt,
    this.cancelledAt,
  });

  final int? id;
  final DateTime date;
  final BookingDirection direction;
  final String description;

  /// Geschäftspartner (Lieferant bei Ausgaben, Kunde bei Einnahmen).
  final String counterparty;

  final Money net;
  final Money vat;
  final Money gross;

  /// Angewandter Steuersatz in Promille (200 = 20 %).
  final int vatPermille;

  final int? categoryId;
  final PaymentMethod paymentMethod;

  /// Relativer Pfad der ersten Belegseite im App-Dokumentenverzeichnis.
  /// Seit Schema 8 stehen alle Seiten in `receipt_pages` ([ReceiptPage]);
  /// dieses Feld spiegelt die erste Seite, damit Liste und Export ohne
  /// zusätzliche Abfrage wissen, ob ein Foto vorhanden ist.
  final String? imagePath;

  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Zeitpunkt der Stornierung, `null` = gültiger Beleg. Wird nur von
  /// `ReceiptRepository.cancel` geschrieben, nie über [toMap].
  final DateTime? cancelledAt;

  bool get isCancelled => cancelledAt != null;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  /// Vorzeichenbehafteter Bruttobetrag für Saldenrechnungen.
  Money get signedGross =>
      direction == BookingDirection.income ? gross : -gross;

  Receipt copyWith({
    int? id,
    DateTime? date,
    BookingDirection? direction,
    String? description,
    String? counterparty,
    Money? net,
    Money? vat,
    Money? gross,
    int? vatPermille,
    int? categoryId,
    bool clearCategory = false,
    PaymentMethod? paymentMethod,
    String? imagePath,
    bool clearImage = false,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      date: date ?? this.date,
      direction: direction ?? this.direction,
      description: description ?? this.description,
      counterparty: counterparty ?? this.counterparty,
      net: net ?? this.net,
      vat: vat ?? this.vat,
      gross: gross ?? this.gross,
      vatPermille: vatPermille ?? this.vatPermille,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'date': date.toIso8601String().substring(0, 10),
    'direction': direction.name,
    'description': description,
    'counterparty': counterparty,
    'net_cents': net.cents,
    'vat_cents': vat.cents,
    'gross_cents': gross.cents,
    'vat_permille': vatPermille,
    'category_id': categoryId,
    'payment_method': paymentMethod.name,
    'image_path': imagePath,
    'note': note,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  static Receipt fromMap(Map<String, Object?> map) => Receipt(
    id: map['id'] as int?,
    date: DateTime.parse(map['date'] as String),
    direction: (map['direction'] as String) == 'income'
        ? BookingDirection.income
        : BookingDirection.expense,
    description: map['description'] as String? ?? '',
    counterparty: map['counterparty'] as String? ?? '',
    net: Money(map['net_cents'] as int? ?? 0),
    vat: Money(map['vat_cents'] as int? ?? 0),
    gross: Money(map['gross_cents'] as int? ?? 0),
    vatPermille: map['vat_permille'] as int? ?? 0,
    categoryId: map['category_id'] as int?,
    paymentMethod: PaymentMethod.fromName(map['payment_method'] as String?),
    imagePath: map['image_path'] as String?,
    note: map['note'] as String? ?? '',
    createdAt: _parseOrNull(map['created_at']),
    updatedAt: _parseOrNull(map['updated_at']),
    cancelledAt: _parseOrNull(map['cancelled_at']),
  );

  static DateTime? _parseOrNull(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}

/// Eine Seite (ein Foto) eines Belegs, seit Schema 8 (Lastenheft L-2.15).
class ReceiptPage {
  const ReceiptPage({
    required this.receiptId,
    required this.position,
    required this.imagePath,
    this.createdAt,
  });

  final int receiptId;

  /// Reihenfolge ab 1, lückenlos.
  final int position;

  /// Relativer Pfad wie bei [Receipt.imagePath].
  final String imagePath;
  final DateTime? createdAt;

  static ReceiptPage fromMap(Map<String, Object?> map) => ReceiptPage(
    receiptId: map['receipt_id'] as int,
    position: map['position'] as int,
    imagePath: map['image_path'] as String,
    createdAt: Receipt._parseOrNull(map['created_at']),
  );
}

/// Kommentar zu einem Beleg (Lastenheft L-2.17). Nur anhängbar: ein
/// Kommentar wird nie geändert oder gelöscht, damit der gebuchte Beleg
/// unverändert bleibt und jede Ergänzung mit Zeitpunkt nachvollziehbar ist
/// (GoBD Rz. 58 ff., § 131 Abs 1 Z 8 BAO).
class ReceiptComment {
  const ReceiptComment({
    this.id,
    required this.receiptId,
    required this.text,
    required this.createdAt,
  });

  final int? id;
  final int receiptId;
  final String text;
  final DateTime createdAt;

  static ReceiptComment fromMap(Map<String, Object?> map) => ReceiptComment(
    id: map['id'] as int?,
    receiptId: map['receipt_id'] as int,
    text: map['text'] as String? ?? '',
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// Buchhalterische Kategorie. Die Kontonummern erlauben später einen sauberen
/// DATEV-/BMD-Export, ohne dass der Nutzer je ein Konto sehen muss.
class ExpenseCategory {
  const ExpenseCategory({
    this.id,
    required this.name,
    required this.direction,
    this.datevAccount,
    this.isSystem = false,
  });

  final int? id;
  final String name;
  final BookingDirection direction;

  /// Sachkonto nach SKR03/SKR04-Logik (DE) bzw. Einheitskontenrahmen (AT).
  final String? datevAccount;

  /// Vorgegebene Kategorie, die nicht gelöscht werden kann.
  final bool isSystem;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'direction': direction.name,
    'datev_account': datevAccount,
    'is_system': isSystem ? 1 : 0,
  };

  static ExpenseCategory fromMap(Map<String, Object?> map) => ExpenseCategory(
    id: map['id'] as int?,
    name: map['name'] as String,
    direction: (map['direction'] as String) == 'income'
        ? BookingDirection.income
        : BookingDirection.expense,
    datevAccount: map['datev_account'] as String?,
    isSystem: (map['is_system'] as int? ?? 0) == 1,
  );
}
