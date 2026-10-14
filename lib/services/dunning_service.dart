import '../core/formatting.dart';
import '../domain/dunning.dart';
import '../domain/invoice.dart';
import '../domain/money.dart';
import 'dunning_calculator.dart';
import 'invoice_texts.dart';

/// Entwurf eines Mahnschreibens samt Zinsabschnitten.
class DunningDraft {
  const DunningDraft(this.notice, this.interest);

  final DunningNotice notice;
  final InterestResult interest;
}

/// Stellt Zahlungserinnerung bzw. Mahnung zusammen (L-3.10, L-3.27 bis
/// L-3.30). Ohne Datenbank und Oberfläche, damit es testbar bleibt.
class DunningService {
  const DunningService._();

  /// Nächste Mahnstufe nach den nicht stornierten Schreiben.
  static int nextLevel(List<DunningNotice> notices) =>
      notices.where((n) => !n.isCancelled).length + 1;

  /// Maßgebliche Zahlungsfrist: die neue Frist des letzten nicht
  /// stornierten Schreibens, sonst die Fälligkeit der Rechnung. Die
  /// Rechnung selbst bleibt unverändert (GR-8); die neue Frist steht im
  /// Schreiben (`dunning_notices.new_due_date`).
  static DateTime? effectiveDueDate(Invoice invoice, DunningNotice? latest) {
    if (latest != null && !latest.isCancelled) return latest.newDueDate;
    return invoice.dueDate;
  }

  /// „Überfällig – erinnern/mahnen“ erst, wenn die maßgebliche Frist
  /// abgelaufen ist, also ab dem Tag nach der Frist.
  static bool needsReminder(
    Invoice invoice,
    DunningNotice? latest,
    DateTime today,
  ) {
    if (invoice.status != InvoiceStatus.issued) return false;
    final due = effectiveDueDate(invoice, latest);
    if (due == null) return false;
    final day = DateTime(today.year, today.month, today.day);
    return DateTime(due.year, due.month, due.day).isBefore(day);
  }

  /// Offene Hauptforderung: Bruttobetrag der Rechnung.
  static Money principalOf(Invoice invoice) => invoice.grossTotal;

  static DunningDraft compose({
    required Invoice invoice,
    required List<DunningNotice> previous,
    required DunningRules rules,
    required bool business,
    required DateTime issuedOn,
    required DateTime newDueDate,
    required Money fee,
    required bool withInterest,
    int? rateBp,
    required bool withFlatFee,
  }) {
    final active = previous.where((n) => !n.isCancelled).toList()
      ..sort((a, b) => a.level.compareTo(b.level));
    final last = active.isEmpty ? null : active.last;
    final level = active.length + 1;
    final principal = principalOf(invoice);
    final interest = withInterest && invoice.dueDate != null
        ? DunningCalculator.interest(
            principal: principal,
            dueDate: invoice.dueDate!,
            until: issuedOn,
            rules: rules,
            business: business,
            overrideRateBp: rateBp,
          )
        : InterestResult.none;
    final flat = business && (withFlatFee || (last?.flatFee.cents ?? 0) > 0)
        ? rules.flatFee
        : const Money.zero();
    final feesTotal = (last?.feesTotal ?? const Money.zero()) + fee;
    final appliedRate = interest.periods.isEmpty
        ? 0
        : interest.periods.last.rateBp;
    final draft = DunningNotice(
      invoiceId: invoice.id ?? 0,
      level: level,
      issuedOn: issuedOn,
      newDueDate: newDueDate,
      principal: principal,
      fee: fee,
      feesTotal: feesTotal,
      interest: interest.amount,
      interestRateBp: appliedRate,
      flatFee: flat,
      text: '',
    );
    return DunningDraft(
      DunningNotice(
        invoiceId: draft.invoiceId,
        level: level,
        issuedOn: issuedOn,
        newDueDate: newDueDate,
        principal: principal,
        fee: fee,
        feesTotal: feesTotal,
        interest: interest.amount,
        interestRateBp: appliedRate,
        flatFee: flat,
        text: bodyText(invoice: invoice, notice: draft),
      ),
      interest,
    );
  }

  /// Sachlicher Text ohne Drohungen (L-3.29).
  static String bodyText({
    required Invoice invoice,
    required DunningNotice notice,
  }) {
    final ref =
        'unsere Rechnung ${invoice.number} vom ${Fmt.date(invoice.issueDate)}';
    final due = invoice.dueDate == null
        ? ''
        : ' war am ${Fmt.date(invoice.dueDate!)} fällig und';
    final pay = InvoiceTexts.dunningPay(
      Fmt.money(notice.total),
      Fmt.date(notice.newDueDate),
    );
    if (notice.level <= 1) {
      return 'Vielleicht ist es im Alltag untergegangen: $ref$due ist noch '
          'offen. $pay ${InvoiceTexts.dunningAlreadyPaid}';
    }
    return '${ref[0].toUpperCase()}${ref.substring(1)}$due ist trotz '
        'unserer bisherigen Erinnerung noch nicht beglichen. $pay '
        '${InvoiceTexts.dunningAlreadyPaid}';
  }

  /// Hinweis bei Verbraucherinnen neben den Mahnkosten (P-R32).
  static const consumerFeeHint =
      'Bei Privatkunden sind nur angemessene, tatsächlich entstandene '
      'Mahnkosten zulässig – 10 € können zu hoch sein.';
}
