/// Währung des Unternehmens (Hauswährung) und Fremdwährungen (Umbauplan AP2,
/// `docs/maerkte/Umbauplan_Laender.md`). Beträge bleiben ganzzahlige
/// Hundertstel (`Money`); die Währung sagt nur, wovon.
class Currency {
  const Currency(this.code, this.symbol);

  /// ISO 4217, z. B. `EUR`.
  final String code;

  /// Zeichen für die Anzeige, z. B. `€`.
  final String symbol;

  static const eur = Currency('EUR', '€');
  static const gbp = Currency('GBP', '£');
  static const usd = Currency('USD', r'$');

  /// Hauswährung des geöffneten Unternehmens. Ergibt sich aus dem Land
  /// (`TaxProfile.currency`) und wird mit `Fmt.setCountry` gesetzt; eine
  /// eigene Spalte in der Datenbank ist dafür nicht nötig.
  static Currency home = eur;

  /// Ist [code] eine Fremdwährung gegenüber der Hauswährung?
  static bool isForeign(String code) =>
      code.isNotEmpty && code.toUpperCase() != home.code;
}
