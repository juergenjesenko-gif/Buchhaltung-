/// Vertragsarchiv (Lastenheft 5.23, Spezifikation FA-16.x). Reines Dart.
library;

import 'money.dart';

enum ContractType {
  rent('Miete'),
  lease('Pacht'),
  leasing('Leasing'),
  easement('Dienstbarkeit'),
  insurance('Versicherung'),
  loan('Darlehen'),
  service('Dienstvertrag'),
  work('Werkvertrag'),
  purchase('Kaufvertrag'),
  other('Sonstiger Vertrag');

  const ContractType(this.label);
  final String label;

  static ContractType fromName(String? name) =>
      values.firstWhere((t) => t.name == name, orElse: () => other);
}

/// Zahlungsrhythmus der Rate.
enum PaymentRhythm {
  monthly('monatlich', 1),
  quarterly('vierteljährlich', 3),
  halfYearly('halbjährlich', 6),
  yearly('jährlich', 12),
  none('keine regelmäßige Zahlung', 0);

  const PaymentRhythm(this.label, this.months);
  final String label;
  final int months;

  static PaymentRhythm fromName(String? name) =>
      values.firstWhere((r) => r.name == name, orElse: () => none);
}

enum NoticeUnit {
  days('Tage'),
  weeks('Wochen'),
  months('Monate');

  const NoticeUnit(this.label);
  final String label;

  static NoticeUnit fromName(String? name) =>
      values.firstWhere((u) => u.name == name, orElse: () => months);
}

class Contract {
  const Contract({
    this.id,
    required this.type,
    required this.title,
    this.partner = '',
    this.startDate,
    this.endDate,
    this.noticeValue,
    this.noticeUnit = NoticeUnit.months,
    this.rate = const Money.zero(),
    this.rhythm = PaymentRhythm.none,
    this.vatPermille = 0,
    this.indexation = '',
    this.nextIndexDate,
    this.comment = '',
    this.ocrText = '',
    this.originalPath,
    this.pages = const [],
  });

  final int? id;
  final ContractType type;
  final String title;
  final String partner;
  final DateTime? startDate;

  /// Vertragsende; `null` = unbefristet.
  final DateTime? endDate;

  /// Kündigungsfrist, z. B. 3 Monate.
  final int? noticeValue;
  final NoticeUnit noticeUnit;

  /// Rate brutto je Fälligkeit.
  final Money rate;
  final PaymentRhythm rhythm;
  final int vatPermille;

  /// Wertsicherung/Indexierung als Text (z. B. „VPI 2020, jährlich“).
  final String indexation;
  final DateTime? nextIndexDate;
  final String comment;

  /// Lokal erkannter Text aller Seiten (Zeilen mit „[S. n]“-Markern).
  final String ocrText;

  /// Originaldatei (PDF) im Belegspeicher, falls geteilt.
  final String? originalPath;

  /// Relative Pfade der Seitenbilder in Reihenfolge.
  final List<String> pages;

  Contract copyWith({
    int? id,
    ContractType? type,
    String? title,
    String? partner,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEnd = false,
    int? noticeValue,
    bool clearNotice = false,
    NoticeUnit? noticeUnit,
    Money? rate,
    PaymentRhythm? rhythm,
    int? vatPermille,
    String? indexation,
    DateTime? nextIndexDate,
    bool clearIndexDate = false,
    String? comment,
    String? ocrText,
    String? originalPath,
    List<String>? pages,
  }) => Contract(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    partner: partner ?? this.partner,
    startDate: startDate ?? this.startDate,
    endDate: clearEnd ? null : (endDate ?? this.endDate),
    noticeValue: clearNotice ? null : (noticeValue ?? this.noticeValue),
    noticeUnit: noticeUnit ?? this.noticeUnit,
    rate: rate ?? this.rate,
    rhythm: rhythm ?? this.rhythm,
    vatPermille: vatPermille ?? this.vatPermille,
    indexation: indexation ?? this.indexation,
    nextIndexDate: clearIndexDate
        ? null
        : (nextIndexDate ?? this.nextIndexDate),
    comment: comment ?? this.comment,
    ocrText: ocrText ?? this.ocrText,
    originalPath: originalPath ?? this.originalPath,
    pages: pages ?? this.pages,
  );

  static String? _day(DateTime? d) => d?.toIso8601String().substring(0, 10);
  static DateTime? _parse(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.parse(v) : null;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'type': type.name,
    'title': title,
    'partner': partner,
    'start_date': _day(startDate),
    'end_date': _day(endDate),
    'notice_value': noticeValue,
    'notice_unit': noticeUnit.name,
    'rate_cents': rate.cents,
    'rhythm': rhythm.name,
    'vat_permille': vatPermille,
    'indexation': indexation,
    'next_index_date': _day(nextIndexDate),
    'comment': comment,
    'ocr_text': ocrText,
    'original_path': originalPath,
    'updated_at': DateTime.now().toIso8601String(),
  };

  static Contract fromMap(
    Map<String, Object?> m, [
    List<String> pages = const [],
  ]) => Contract(
    id: m['id'] as int?,
    type: ContractType.fromName(m['type'] as String?),
    title: m['title'] as String? ?? '',
    partner: m['partner'] as String? ?? '',
    startDate: _parse(m['start_date']),
    endDate: _parse(m['end_date']),
    noticeValue: m['notice_value'] as int?,
    noticeUnit: NoticeUnit.fromName(m['notice_unit'] as String?),
    rate: Money(m['rate_cents'] as int? ?? 0),
    rhythm: PaymentRhythm.fromName(m['rhythm'] as String?),
    vatPermille: m['vat_permille'] as int? ?? 0,
    indexation: m['indexation'] as String? ?? '',
    nextIndexDate: _parse(m['next_index_date']),
    comment: m['comment'] as String? ?? '',
    ocrText: m['ocr_text'] as String? ?? '',
    originalPath: m['original_path'] as String?,
    pages: pages,
  );
}
