/// Fremdwährung bei Eingangsbelegen (Lastenheft L-2.24 bis L-2.26).
///
/// **Kursdarstellung:** Einheiten der fremden Währung je 1 Euro, mal
/// [exchangeRateScale] als Ganzzahl. So notiert die EZB ihre Referenzkurse
/// (z. B. `USD 1.0823` → `1082300`), und so veröffentlicht auch das BMF seine
/// Durchschnittskurse. Ein Kurs wird damit nie invertiert, und eine
/// abgeschriebene Zahl lässt sich direkt mit der Quelle vergleichen.
library;

/// Skalierung des Kurses: sechs Nachkommastellen. Die EZB veröffentlicht
/// höchstens fünf signifikante Stellen (z. B. `1.0823`, `161.25`), sechs
/// Nachkommastellen fassen also jeden Referenzkurs exakt.
const exchangeRateScale = 1000000;

/// Herkunft eines Umrechnungskurses. Der Name ist der gespeicherte Wert.
enum ExchangeRateSource {
  /// Vom BMF veröffentlichter Monatsdurchschnittskurs, von Hand übernommen
  /// (§ 20 Abs 6 UStG AT, § 16 Abs 6 UStG DE).
  bmfMonthly('bmf_monthly', 'BMF-Monatskurs (manuell übernommen)'),

  /// Selbst gebildetes Mittel der EZB-Tageskurse des Monats – nur eine
  /// Näherung an den BMF-Kurs (Spezifikation 14, P-S23, P-S24).
  ecbMonthlyAvg('ecb_monthly_avg', 'EZB-Monatsmittel – Näherung an BMF-Kurs'),

  /// EZB-Tageskurs; für die Umsatzsteuer nur mit Genehmigung des Finanzamts.
  ecbDaily('ecb_daily', 'EZB-Tageskurs (Genehmigung Finanzamt)'),

  /// Von Hand eingetragener Kurs.
  manual('manual', 'Manuell'),

  /// Kurs laut Bankabrechnung.
  bank('bank', 'Bankkurs');

  const ExchangeRateSource(this.code, this.label);

  final String code;
  final String label;

  static ExchangeRateSource? fromCode(String? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Quellenhinweis bei jedem EZB-Kurs (L-19.29).
const ecbSourceNotice = 'EZB-Referenzkurs, ohne Gewähr';
