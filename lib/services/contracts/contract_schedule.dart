/// Fristen, Zahlungsplan, Abgleich und Aufbewahrung von Verträgen
/// (Lastenheft L-23.2 bis L-23.4, Spezifikation FA-16.4 bis FA-16.7).
library;

import '../../domain/contract.dart';
import '../../domain/receipt.dart';
import '../deadline_calculator.dart' show Deadline;
import '../vat_calculator.dart';

enum PaymentStatus { paid, differs, missing }

/// Eine erwartete Rate und der zugeordnete Beleg.
class ExpectedPayment {
  const ExpectedPayment(this.due, this.status, [this.receipt]);

  final DateTime due;
  final PaymentStatus status;
  final Receipt? receipt;
}

class ContractSchedule {
  ContractSchedule._();

  /// So viele Tage vor oder nach der Fälligkeit zählt ein Beleg als Rate.
  static const matchToleranceDays = 20;

  /// Fälligkeiten ab Beginn im Rhythmus bis [until] bzw. Vertragsende.
  static List<DateTime> dueDates(Contract c, DateTime until, {int max = 600}) {
    final start = c.startDate;
    if (start == null || c.rhythm == PaymentRhythm.none) return const [];
    final out = <DateTime>[];
    for (var i = 0; i < max; i++) {
      final d = _addMonths(start, i * c.rhythm.months);
      if (d.isAfter(until)) break;
      if (c.endDate != null && d.isAfter(c.endDate!)) break;
      out.add(d);
    }
    return out;
  }

  /// Letzter Tag, an dem die Kündigung zugehen muss: Vertragsende minus
  /// Kündigungsfrist. `null` ohne Ende oder ohne Frist (unbefristet: jederzeit
  /// mit Frist).
  static DateTime? noticeDeadline(Contract c) {
    final end = c.endDate;
    final v = c.noticeValue;
    if (end == null || v == null || v <= 0) return null;
    return switch (c.noticeUnit) {
      NoticeUnit.days => end.subtract(Duration(days: v)),
      NoticeUnit.weeks => end.subtract(Duration(days: 7 * v)),
      NoticeUnit.months => _addMonths(end, -v),
    };
  }

  /// Termine für die Termin-Box (L-23.3): Kündigen bis, Vertragsende,
  /// Indexanpassung – ab [today] (einschließlich).
  static List<Deadline> deadlines(
    Iterable<Contract> contracts,
    DateTime today,
  ) {
    final day = DateTime(today.year, today.month, today.day);
    final out = <Deadline>[];
    for (final c in contracts) {
      final notice = noticeDeadline(c);
      if (notice != null && !notice.isBefore(day)) {
        out.add(
          Deadline(
            date: notice,
            label: 'Kündigen bis: ${c.title}',
            legalRef: 'Vertrag',
          ),
        );
      }
      final end = c.endDate;
      if (end != null && !end.isBefore(day)) {
        out.add(
          Deadline(
            date: end,
            label: 'Vertragsende: ${c.title}',
            legalRef: 'Vertrag',
          ),
        );
      }
      final index = c.nextIndexDate;
      if (index != null && !index.isBefore(day)) {
        out.add(
          Deadline(
            date: index,
            label: 'Indexanpassung: ${c.title}',
            legalRef: 'Vertrag',
          ),
        );
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Abgleich Rate laut Vertrag gegen gebuchte Zahlungen (L-23.4): die
  /// letzten [count] Fälligkeiten bis [today].
  static List<ExpectedPayment> match(
    Contract c,
    List<Receipt> linked,
    DateTime today, {
    int count = 12,
  }) {
    final dues = dueDates(c, today);
    final recent = dues.length > count
        ? dues.sublist(dues.length - count)
        : dues;
    final used = <int>{};
    final out = <ExpectedPayment>[];
    for (final due in recent) {
      Receipt? best;
      var bestDiff = matchToleranceDays + 1;
      for (var i = 0; i < linked.length; i++) {
        if (used.contains(i)) continue;
        final diff = linked[i].date.difference(due).inDays.abs();
        if (diff <= matchToleranceDays && diff < bestDiff) {
          best = linked[i];
          bestDiff = diff;
        }
      }
      if (best == null) {
        out.add(ExpectedPayment(due, PaymentStatus.missing));
        continue;
      }
      used.add(linked.indexOf(best));
      out.add(
        ExpectedPayment(
          due,
          best.gross == c.rate ? PaymentStatus.paid : PaymentStatus.differs,
          best,
        ),
      );
    }
    return out;
  }

  /// Nächste offene Fälligkeit ab [today] als Vorschlag zum Buchen.
  static DateTime? nextDue(Contract c, DateTime today) {
    final dues = dueDates(c, DateTime(today.year + 2, today.month, today.day));
    final day = DateTime(today.year, today.month, today.day);
    for (final d in dues) {
      if (!d.isBefore(day)) return d;
    }
    return null;
  }

  /// Ende der Aufbewahrung (L-23.2): Ende des Kalenderjahres von Vertragsende
  /// bzw. letzter verknüpfter Buchung, plus [retentionYears] (AT § 132 Abs 1
  /// BAO, DE § 147 Abs 3 und 4 AO; Jahre aus `TaxProfile.retentionYears`).
  /// `null`, solange der Vertrag läuft (unbefristet, ohne Ende).
  static DateTime? retentionUntil(
    Contract c,
    DateTime? lastBooking,
    int retentionYears,
  ) {
    final candidates = [?c.endDate, ?lastBooking];
    if (c.endDate == null) return null;
    final base = candidates.reduce((a, b) => a.isAfter(b) ? a : b);
    return DateTime(base.year + retentionYears, 12, 31);
  }

  /// Vorschlag für eine Ausgabe zur nächsten Rate (nur Vorschlag, L-23.4).
  static Receipt suggestedBooking(Contract c, DateTime due) {
    // Steuer als Restgröße (GR-2), ganzzahlig über VatCalculator.
    final split = VatCalculator.fromGross(c.rate, c.vatPermille);
    return Receipt(
      date: due,
      direction: BookingDirection.expense,
      description: '${c.type.label}: ${c.title}',
      counterparty: c.partner,
      net: split.net,
      vat: split.vat,
      gross: split.gross,
      vatPermille: c.vatPermille,
    );
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.year * 12 + (d.month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > last ? last : d.day);
  }
}
