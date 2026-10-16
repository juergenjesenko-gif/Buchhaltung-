/// Anlagevermögen (Spezifikation FA-15.1 ff., GR-15). Reines Dart.
library;

import 'money.dart';

/// Abschreibungsart.
enum DepreciationMethod {
  /// Lineare AfA über die Nutzungsdauer.
  linear,

  /// Geringwertiges Wirtschaftsgut: sofort im Anschaffungsjahr.
  gwg,

  /// Sammelposten (nur DE, § 6 Abs 2a EStG): fünf gleiche Jahresteile.
  pool;

  String get label => switch (this) {
    linear => 'Linear über die Nutzungsdauer',
    gwg => 'Geringwertig – sofort abschreiben',
    pool => 'Sammelposten – 5 Jahre',
  };

  static DepreciationMethod fromName(String? name) => values.firstWhere(
    (m) => m.name == name,
    orElse: () => DepreciationMethod.linear,
  );
}

/// Grund des Ausscheidens.
enum DisposalKind {
  scrapped,
  lost,
  sold,
  extraordinary;

  String get label => switch (this) {
    scrapped => 'Verschrottet / entsorgt',
    lost => 'Verloren / gestohlen',
    sold => 'Verkauft',
    extraordinary => 'Außerplanmäßig abgeschrieben (Schaden, Wertverlust)',
  };

  static DisposalKind? fromName(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Ein Wirtschaftsgut des Anlagevermögens.
class FixedAsset {
  const FixedAsset({
    this.id,
    this.receiptId,
    required this.name,
    required this.acquiredOn,
    required this.cost,
    required this.categoryKey,
    required this.usefulLifeYears,
    this.method = DepreciationMethod.linear,
    this.lifeReason = '',
    this.comment = '',
    this.disposedOn,
    this.disposalKind,
    this.disposalProceeds = const Money.zero(),
    this.disposalReceiptId,
    this.disposalComment = '',
  });

  final int? id;

  /// Beleg der Anschaffung, falls vorhanden.
  final int? receiptId;
  final String name;

  /// Anschaffungs- bzw. Inbetriebnahmedatum.
  final DateTime acquiredOn;

  /// Anschaffungskosten: netto, beim Kleinunternehmer brutto (nicht
  /// abziehbare Vorsteuer gehört dazu, AT § 6 Z 11 EStG, DE § 9b Abs 1 EStG).
  final Money cost;

  /// Schlüssel aus `DepreciationRules.classes`.
  final String categoryKey;
  final int usefulLifeYears;
  final DepreciationMethod method;

  /// Begründung, wenn die Nutzungsdauer vom Vorschlag abweicht.
  final String lifeReason;
  final String comment;

  final DateTime? disposedOn;
  final DisposalKind? disposalKind;
  final Money disposalProceeds;
  final int? disposalReceiptId;
  final String disposalComment;

  bool get isDisposed => disposedOn != null;

  FixedAsset copyWith({
    int? id,
    String? name,
    DateTime? acquiredOn,
    Money? cost,
    String? categoryKey,
    int? usefulLifeYears,
    DepreciationMethod? method,
    String? lifeReason,
    String? comment,
    DateTime? disposedOn,
    DisposalKind? disposalKind,
    Money? disposalProceeds,
    int? disposalReceiptId,
    String? disposalComment,
  }) => FixedAsset(
    id: id ?? this.id,
    receiptId: receiptId,
    name: name ?? this.name,
    acquiredOn: acquiredOn ?? this.acquiredOn,
    cost: cost ?? this.cost,
    categoryKey: categoryKey ?? this.categoryKey,
    usefulLifeYears: usefulLifeYears ?? this.usefulLifeYears,
    method: method ?? this.method,
    lifeReason: lifeReason ?? this.lifeReason,
    comment: comment ?? this.comment,
    disposedOn: disposedOn ?? this.disposedOn,
    disposalKind: disposalKind ?? this.disposalKind,
    disposalProceeds: disposalProceeds ?? this.disposalProceeds,
    disposalReceiptId: disposalReceiptId ?? this.disposalReceiptId,
    disposalComment: disposalComment ?? this.disposalComment,
  );

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'receipt_id': receiptId,
    'name': name,
    'acquired_on': _day(acquiredOn),
    'cost_cents': cost.cents,
    'category_key': categoryKey,
    'useful_life_years': usefulLifeYears,
    'method': method.name,
    'life_reason': lifeReason,
    'comment': comment,
    'disposed_on': disposedOn == null ? null : _day(disposedOn!),
    'disposal_kind': disposalKind?.name,
    'disposal_proceeds_cents': disposalProceeds.cents,
    'disposal_receipt_id': disposalReceiptId,
    'disposal_comment': disposalComment,
    'updated_at': DateTime.now().toIso8601String(),
  };

  static FixedAsset fromMap(Map<String, Object?> m) => FixedAsset(
    id: m['id'] as int?,
    receiptId: m['receipt_id'] as int?,
    name: m['name'] as String? ?? '',
    acquiredOn: DateTime.parse(m['acquired_on'] as String),
    cost: Money(m['cost_cents'] as int? ?? 0),
    categoryKey: m['category_key'] as String? ?? 'other',
    usefulLifeYears: m['useful_life_years'] as int? ?? 1,
    method: DepreciationMethod.fromName(m['method'] as String?),
    lifeReason: m['life_reason'] as String? ?? '',
    comment: m['comment'] as String? ?? '',
    disposedOn: m['disposed_on'] == null
        ? null
        : DateTime.parse(m['disposed_on'] as String),
    disposalKind: DisposalKind.fromName(m['disposal_kind'] as String?),
    disposalProceeds: Money(m['disposal_proceeds_cents'] as int? ?? 0),
    disposalReceiptId: m['disposal_receipt_id'] as int?,
    disposalComment: m['disposal_comment'] as String? ?? '',
  );
}

/// Wie die Jahres-AfA im ersten Jahr anteilig wird.
enum DepreciationTiming {
  /// AT § 7 Abs 2 EStG: Inbetriebnahme im zweiten Halbjahr → halbe AfA.
  halfYear,

  /// DE § 7 Abs 1 Satz 4 EStG: monatsgenau (pro rata temporis).
  monthly,
}

/// Vorschlag der Nutzungsdauer für eine Anlagenart.
class AssetClass {
  const AssetClass(
    this.key,
    this.label,
    this.years,
    this.legalRef, {
    this.minYears,
  });

  final String key;
  final String label;
  final int years;
  final String legalRef;

  /// Gesetzliche Mindestnutzungsdauer (z. B. PKW AT 8 Jahre).
  final int? minYears;
}

/// Abschreibungsregeln eines Landes.
class DepreciationRules {
  const DepreciationRules({
    required this.timing,
    required this.timingLegalRef,
    required this.gwgLimit,
    required this.gwgLegalRef,
    required this.gwgLimitIsNet,
    required this.poolRange,
    required this.registerLegalRef,
    required this.classes,
  });

  final DepreciationTiming timing;
  final String timingLegalRef;

  /// Grenze für geringwertige Wirtschaftsgüter (einschließlich).
  final Money gwgLimit;
  final String gwgLegalRef;

  /// Grenze immer am Nettobetrag gemessen (auch ohne Vorsteuerabzug)?
  final bool gwgLimitIsNet;

  /// Sammelposten von–bis (netto) oder `null`, wenn es keinen gibt.
  final (Money, Money)? poolRange;

  /// Pflicht zum Anlagenverzeichnis.
  final String registerLegalRef;
  final List<AssetClass> classes;

  AssetClass classFor(String key) =>
      classes.firstWhere((c) => c.key == key, orElse: () => classes.last);
}
