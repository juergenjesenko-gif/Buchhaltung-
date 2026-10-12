import '../../data/exchange_rate_repository.dart';
import '../../domain/exchange_rate.dart';
import 'currency_converter.dart';
import 'ecb_rates.dart';

/// Ein ermittelter Kurs samt Herkunft.
class FxQuote {
  const FxQuote({
    required this.rateMicros,
    required this.rateDate,
    required this.source,
    this.days = 1,
    this.partialMonth = false,
  });

  final int rateMicros;

  /// `YYYY-MM` beim Monatsmittel, sonst `YYYY-MM-DD` des verwendeten Kurses.
  final String rateDate;
  final ExchangeRateSource source;

  /// Anzahl der Tageskurse im Mittel.
  final int days;

  /// Der Monat ist noch nicht abgeschlossen; das Mittel ist vorläufig.
  final bool partialMonth;
}

/// Ermittelt den Umsatzsteuer-Kurs eines Belegs (L-2.25): Monatsmittel des
/// Belegmonats, Tageskurs nur bei [dailyApproved]. Fehlen Kurse im lokalen
/// Speicher, lädt der Dienst sie bei der EZB – er wird nur vom Knopf
/// „Kurs abrufen“ aufgerufen (L-19.29).
class FxRateService {
  FxRateService(this._repo, {EcbClient? client})
    : _client = client ?? EcbClient();

  final ExchangeRateRepository _repo;
  final EcbClient _client;

  Future<FxQuote?> quote({
    required String currency,
    required DateTime date,
    required bool dailyApproved,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final cached = await _fromCache(currency, date, dailyApproved, now);
    if (cached != null) return cached;
    final rates = await _client.fetch(EcbClient.sourceFor(date, now));
    await _repo.store(rates, now: now);
    return _fromCache(currency, date, dailyApproved, now, afterFetch: true);
  }

  Future<FxQuote?> _fromCache(
    String currency,
    DateTime date,
    bool daily,
    DateTime now, {
    bool afterFetch = false,
  }) async {
    if (daily) {
      final rate = await _repo.onOrBefore(currency, date);
      if (rate == null) return null;
      return FxQuote(
        rateMicros: rate.rateMicros,
        rateDate: rate.date.toIso8601String().substring(0, 10),
        source: ExchangeRateSource.ecbDaily,
      );
    }
    final rates = await _repo.month(currency, date.year, date.month);
    if (rates.isEmpty) return null;
    final monthOver = !DateTime(date.year, date.month + 1).isAfter(now);
    // Letzter Kurs höchstens vier Tage vor Monatsende (Wochenende, Feiertag).
    final complete =
        monthOver &&
        DateTime.utc(
              date.year,
              date.month + 1,
              0,
            ).difference(rates.last.date).inDays <=
            4;
    // Ein unvollständiger Monat wird zuerst neu geladen.
    if (!complete && !afterFetch) return null;
    return FxQuote(
      rateMicros: CurrencyConverter.average([
        for (final r in rates) r.rateMicros,
      ])!,
      rateDate: _month(date),
      source: ExchangeRateSource.ecbMonthlyAvg,
      days: rates.length,
      partialMonth: !complete,
    );
  }

  static String _month(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
