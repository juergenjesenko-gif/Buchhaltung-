import 'invoice.dart';
import 'money.dart';

/// Ein Artikel oder eine wiederkehrende Leistung (Lastenheft L-11.1).
/// Bewusst schlank: keine Lagerführung (L-11.3 ist Stufe B).
class Article {
  const Article({
    this.id,
    this.number = '',
    required this.name,
    this.description = '',
    this.unit = 'Stk',
    required this.unitPrice,
    required this.vatPermille,
  });

  final int? id;

  /// Artikelnummer, freiwillig; wenn gesetzt, eindeutig (L-11.2).
  final String number;

  /// Bezeichnung, wie sie auf Angebot und Rechnung steht.
  final String name;
  final String description;
  final String unit;

  /// Einzelpreis netto in Cent.
  final Money unitPrice;

  /// Steuersatz in Promille.
  final int vatPermille;

  /// Position zum Artikel; alles bleibt in der Position änderbar (L-11.5).
  InvoiceItem toItem() => InvoiceItem(
    position: 0,
    description: description.trim().isEmpty ? name : '$name\n$description',
    quantityMilli: 1000,
    unit: unit,
    unitPrice: unitPrice,
    vatPermille: vatPermille,
  );

  Article copyWith({int? id}) => Article(
    id: id ?? this.id,
    number: number,
    name: name,
    description: description,
    unit: unit,
    unitPrice: unitPrice,
    vatPermille: vatPermille,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'number': number.trim().isEmpty ? null : number.trim(),
    'name': name,
    'description': description,
    'unit': unit,
    'unit_price_cents': unitPrice.cents,
    'vat_permille': vatPermille,
  };

  static Article fromMap(Map<String, Object?> map) => Article(
    id: map['id'] as int?,
    number: map['number'] as String? ?? '',
    name: map['name'] as String? ?? '',
    description: map['description'] as String? ?? '',
    unit: map['unit'] as String? ?? 'Stk',
    unitPrice: Money(map['unit_price_cents'] as int? ?? 0),
    vatPermille: map['vat_permille'] as int? ?? 0,
  );
}

/// Vorschlag für eine Position: ein Artikel oder eine früher verwendete
/// Position aus Rechnung oder Angebot (Spezifikation FA-5.45).
class PositionSuggestion {
  const PositionSuggestion({
    required this.description,
    required this.unit,
    required this.unitPrice,
    required this.vatPermille,
    this.article,
  });

  final String description;
  final String unit;
  final Money unitPrice;
  final int vatPermille;

  /// Gesetzt, wenn der Vorschlag aus dem Artikelstamm kommt.
  final Article? article;

  bool get isArticle => article != null;

  InvoiceItem toItem() =>
      article?.toItem() ??
      InvoiceItem(
        position: 0,
        description: description,
        quantityMilli: 1000,
        unit: unit,
        unitPrice: unitPrice,
        vatPermille: vatPermille,
      );

  /// Treffer für die Suche nach Bezeichnung oder Artikelnummer (L-11.9).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return description.toLowerCase().contains(q) ||
        (article?.number.toLowerCase().contains(q) ?? false);
  }
}
