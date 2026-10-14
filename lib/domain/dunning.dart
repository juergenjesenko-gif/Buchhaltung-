import 'money.dart';

/// Basiszinssatz ab einem Stichtag, in Basispunkten (1/100 %).
///
/// Zinssätze sind hier Basispunkte statt Promille: der Basiszinssatz hat zwei
/// Nachkommastellen (z. B. 1,27 %), Promille könnten ihn nicht exakt tragen.
class BaseRate {
  const BaseRate(this.validFrom, this.basisPoints);

  final DateTime validFrom;
  final int basisPoints;
}

/// Länderregeln für Zahlungserinnerung und Mahnung (L-3.27 bis L-3.30).
/// Teil des `TaxProfile` (CLAUDE.md Regel 5).
class DunningRules {
  const DunningRules({
    required this.consumerFixedRateBp,
    required this.consumerSurchargeBp,
    required this.businessSurchargeBp,
    required this.consumerInterestLegalRef,
    required this.businessInterestLegalRef,
    required this.baseRates,
    required this.baseRateLegalRef,
    required this.flatFee,
    required this.flatFeeLegalRef,
    required this.consumerDefaultNotice,
    required this.paymentAllocationLegalRef,
  });

  /// Fester Verzugszinssatz für Verbraucher (AT § 1000 ABGB: 4 %), `null`
  /// wenn er sich aus Basiszinssatz + Aufschlag ergibt.
  final int? consumerFixedRateBp;

  /// Aufschlag auf den Basiszinssatz für Verbraucher (DE § 288 Abs 1 BGB).
  final int consumerSurchargeBp;

  /// Aufschlag auf den Basiszinssatz unter Unternehmern
  /// (AT § 456 UGB, DE § 288 Abs 2 BGB).
  final int businessSurchargeBp;

  final String consumerInterestLegalRef;
  final String businessInterestLegalRef;

  /// Basiszinssätze, aufsteigend nach Stichtag. Maßgeblich ist je Halbjahr
  /// der Satz am ersten Tag des Halbjahrs.
  final List<BaseRate> baseRates;
  final String baseRateLegalRef;

  /// Pauschale Betreibungskosten nur unter Unternehmern
  /// (AT § 458 UGB, DE § 288 Abs 5 BGB).
  final Money flatFee;
  final String flatFeeLegalRef;

  /// Hinweis auf Rechnungen an Verbraucher, `null` = keiner. DE: Verzug nach
  /// 30 Tagen nur, wenn darauf hingewiesen wurde (§ 286 Abs 3 BGB).
  final String? consumerDefaultNotice;

  /// Anrechnung einer Zahlung: Kosten, Zinsen, Hauptforderung.
  final String paymentAllocationLegalRef;

  /// Basiszinssatz am Tag [date] (letzter Stichtag ≤ [date]), 0 vor dem
  /// ersten bekannten Stichtag.
  int baseRateOn(DateTime date) {
    var result = 0;
    for (final rate in baseRates) {
      if (!rate.validFrom.isAfter(date)) result = rate.basisPoints;
    }
    return result;
  }

  /// Gesetzlicher Verzugszinssatz am [date] in Basispunkten.
  int statutoryRateBp({required bool business, required DateTime date}) {
    if (!business && consumerFixedRateBp != null) return consumerFixedRateBp!;
    final base = baseRateOn(halfYearStart(date));
    final rate = base + (business ? businessSurchargeBp : consumerSurchargeBp);
    return rate < 0 ? 0 : rate;
  }

  String interestLegalRef({required bool business}) =>
      business ? businessInterestLegalRef : consumerInterestLegalRef;

  /// Ändert sich der Satz je Halbjahr (Basiszinssatz)?
  bool variesByHalfYear({required bool business}) =>
      business || consumerFixedRateBp == null;

  static DateTime halfYearStart(DateTime date) =>
      DateTime(date.year, date.month <= 6 ? 1 : 7, 1);
}

/// Bezeichnung der Mahnstufe: 1 = Zahlungserinnerung, danach 1., 2. … Mahnung.
String dunningTitle(int level) =>
    level <= 1 ? 'Zahlungserinnerung' : '${level - 1}. Mahnung';

/// Kurzbezeichnung für das Symbol in der Rechnungsliste: „Erinnert“,
/// „1. Mahnung“, „2. Mahnung“ …
String dunningBadge(int level) =>
    level <= 1 ? 'Erinnert' : '${level - 1}. Mahnung';

/// Eine gestellte Zahlungserinnerung oder Mahnung. Unveränderlich: Text,
/// Sätze und Beträge sind als Momentaufnahme gespeichert; nur ein Storno mit
/// Begründung ist möglich (L-3.29).
class DunningNotice {
  const DunningNotice({
    this.id,
    required this.invoiceId,
    required this.level,
    required this.issuedOn,
    required this.newDueDate,
    required this.principal,
    required this.fee,
    required this.feesTotal,
    required this.interest,
    required this.interestRateBp,
    required this.flatFee,
    required this.text,
    this.pdfSha256 = '',
    this.cancelledAt,
    this.cancelReason = '',
    this.createdAt,
  });

  final int? id;
  final int invoiceId;
  final int level;
  final DateTime issuedOn;
  final DateTime newDueDate;

  /// Offener Rechnungsbetrag (Hauptforderung).
  final Money principal;

  /// Mahnkosten dieses Schreibens.
  final Money fee;

  /// Mahnkosten aller nicht stornierten Schreiben bis einschließlich diesem.
  final Money feesTotal;

  /// Verzugszinsen seit Fälligkeit bis [issuedOn], kumuliert.
  final Money interest;

  /// Angewandter Zinssatz zum Ausstellungstag (Basispunkte), 0 = ohne Zinsen.
  final int interestRateBp;

  /// Pauschale (nur B2B), kumuliert höchstens einmal.
  final Money flatFee;

  /// Text des Schreibens, wie gesendet.
  final String text;
  final String pdfSha256;
  final DateTime? cancelledAt;
  final String cancelReason;
  final DateTime? createdAt;

  bool get isCancelled => cancelledAt != null;
  String get title => dunningTitle(level);

  /// Nicht umsatzsteuerbare Nebenforderungen.
  Money get costs => feesTotal + interest + flatFee;
  Money get total => principal + costs;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'invoice_id': invoiceId,
    'level': level,
    'issued_on': _day(issuedOn),
    'new_due_date': _day(newDueDate),
    'principal_cents': principal.cents,
    'fee_cents': fee.cents,
    'fees_total_cents': feesTotal.cents,
    'interest_cents': interest.cents,
    'interest_rate_bp': interestRateBp,
    'flat_fee_cents': flatFee.cents,
    'total_cents': total.cents,
    'text': text,
    'pdf_sha256': pdfSha256,
    'cancelled_at': cancelledAt?.toIso8601String(),
    'cancel_reason': cancelReason,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  static DunningNotice fromMap(Map<String, Object?> map) => DunningNotice(
    id: map['id'] as int?,
    invoiceId: map['invoice_id'] as int,
    level: map['level'] as int,
    issuedOn: DateTime.parse(map['issued_on'] as String),
    newDueDate: DateTime.parse(map['new_due_date'] as String),
    principal: Money(map['principal_cents'] as int),
    fee: Money(map['fee_cents'] as int),
    feesTotal: Money(map['fees_total_cents'] as int),
    interest: Money(map['interest_cents'] as int),
    interestRateBp: map['interest_rate_bp'] as int,
    flatFee: Money(map['flat_fee_cents'] as int),
    text: map['text'] as String,
    pdfSha256: map['pdf_sha256'] as String? ?? '',
    cancelledAt: map['cancelled_at'] == null
        ? null
        : DateTime.parse(map['cancelled_at'] as String),
    cancelReason: map['cancel_reason'] as String? ?? '',
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
  );

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
}
