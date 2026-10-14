/// Mehrsprachige Schlüsselwörter der Belegerkennung, datengetrieben statt
/// Einzelfälle im Parser. Eine neue Sprache ist eine neue Zeile je Tabelle.
///
/// Sprachen: DE, EN, SL, HR, IT, HU, CS, SK, PL, FR, ES, NL, DK, SE, NO.
/// Alle Einträge in Kleinbuchstaben; verglichen wird mit dem kleingeschriebenen
/// Zeilentext. Einträge mit Leerzeichen am Rand gelten nur als ganzes Wort
/// (Wortgrenzen werden über [ReceiptKeywords.pattern] erzeugt). ML Kit (Latin)
/// liest diakritische Zeichen oft ohne Akzent; darum stehen beide Formen da.
library;

/// Ein Schlüsselwortbegriff mit Gewicht (Konfidenz bei einem Treffer).
class ReceiptKeyword {
  const ReceiptKeyword(this.text, this.language, {this.weight = 80});

  final String text;
  final String language;
  final int weight;
}

abstract final class ReceiptKeywords {
  /// Zu zahlender Gesamtbetrag (brutto). Gewicht 92: eindeutig „zu zahlen“;
  /// 80: allgemeines „Summe/Total“.
  static const gross = [
    ReceiptKeyword('zu zahlen', 'DE', weight: 92),
    ReceiptKeyword('zahlbetrag', 'DE', weight: 92),
    ReceiptKeyword('gesamtbetrag', 'DE', weight: 92),
    ReceiptKeyword('endbetrag', 'DE', weight: 92),
    ReceiptKeyword('rechnungsbetrag', 'DE', weight: 92),
    ReceiptKeyword('summe', 'DE'),
    ReceiptKeyword('endsumme', 'DE'),
    ReceiptKeyword('gesamtsumme', 'DE'),
    ReceiptKeyword('bruttobetrag', 'DE'),
    ReceiptKeyword('brutto', 'DE/PL'),
    ReceiptKeyword('gesamt', 'DE'),
    ReceiptKeyword('betrag', 'DE'),
    ReceiptKeyword('amount due', 'EN', weight: 92),
    ReceiptKeyword('grand total', 'EN', weight: 92),
    ReceiptKeyword('total due', 'EN', weight: 92),
    ReceiptKeyword('balance due', 'EN', weight: 92),
    ReceiptKeyword('total amount', 'EN', weight: 92),
    ReceiptKeyword('total', 'EN/FR/ES'),
    ReceiptKeyword('za plačilo', 'SL', weight: 92),
    ReceiptKeyword('za placilo', 'SL', weight: 92),
    ReceiptKeyword('skupaj', 'SL'),
    ReceiptKeyword('za platiti', 'HR', weight: 92),
    ReceiptKeyword('ukupno', 'HR'),
    ReceiptKeyword('totale', 'IT'),
    ReceiptKeyword('importo', 'IT'),
    ReceiptKeyword('fizetendő', 'HU', weight: 92),
    ReceiptKeyword('fizetendo', 'HU', weight: 92),
    ReceiptKeyword('összesen', 'HU'),
    ReceiptKeyword('osszesen', 'HU'),
    ReceiptKeyword('k úhradě', 'CS', weight: 92),
    ReceiptKeyword('k uhrade', 'CS', weight: 92),
    ReceiptKeyword('celkem', 'CS'),
    ReceiptKeyword('celkom', 'SK'),
    ReceiptKeyword('spolu', 'SK'),
    ReceiptKeyword('do zapłaty', 'PL', weight: 92),
    ReceiptKeyword('do zaplaty', 'PL', weight: 92),
    ReceiptKeyword('razem', 'PL'),
    ReceiptKeyword('suma', 'PL'),
    ReceiptKeyword('net à payer', 'FR', weight: 92),
    ReceiptKeyword('montant ttc', 'FR', weight: 92),
    ReceiptKeyword('total ttc', 'FR', weight: 92),
    ReceiptKeyword('importe', 'ES'),
    ReceiptKeyword('te betalen', 'NL', weight: 92),
    ReceiptKeyword('totaal', 'NL'),
    ReceiptKeyword('at betale', 'DK/NO', weight: 92),
    ReceiptKeyword('i alt', 'DK'),
    ReceiptKeyword('beløb', 'DK/NO'),
    ReceiptKeyword('belob', 'DK/NO'),
    ReceiptKeyword('bel ob', 'DK/NO'),
    ReceiptKeyword('att betala', 'SE', weight: 92),
    ReceiptKeyword('summa', 'SE'),
    ReceiptKeyword('totalt', 'SE/NO'),
    ReceiptKeyword('å betale', 'NO', weight: 92),
  ];

  /// Nettobetrag bzw. Bemessungsgrundlage.
  static const net = [
    ReceiptKeyword('netto', 'DE/IT/PL/NL/DK/SE/NO'),
    ReceiptKeyword('nettobetrag', 'DE'),
    ReceiptKeyword('excl', 'DE/EN/NL'),
    ReceiptKeyword('net', 'EN'),
    ReceiptKeyword('subtotal', 'EN'),
    ReceiptKeyword('osnova', 'SL/HR'),
    ReceiptKeyword('neto', 'SL/HR/ES'),
    ReceiptKeyword('imponibile', 'IT'),
    ReceiptKeyword('nettó', 'HU'),
    ReceiptKeyword('adóalap', 'HU'),
    ReceiptKeyword('adoalap', 'HU'),
    ReceiptKeyword('základ', 'CS/SK'),
    ReceiptKeyword('zaklad', 'CS/SK'),
    ReceiptKeyword('ht', 'FR'),
    ReceiptKeyword('base imponible', 'ES'),
    ReceiptKeyword('grundlag', 'DK'),
  ];

  /// Umsatzsteuer (Betrag oder Satz). Kurze Abkürzungen nur als ganzes Wort.
  static const tax = [
    ReceiptKeyword('mwst', 'DE'),
    ReceiptKeyword('ust', 'DE'),
    ReceiptKeyword('umsatzsteuer', 'DE'),
    ReceiptKeyword('mehrwertsteuer', 'DE'),
    ReceiptKeyword('vorsteuer', 'DE'),
    ReceiptKeyword('steuer', 'DE'),
    ReceiptKeyword('vat', 'EN'),
    ReceiptKeyword('tax', 'EN'),
    ReceiptKeyword('ddv', 'SL'),
    ReceiptKeyword('pdv', 'HR'),
    ReceiptKeyword('iva', 'IT/ES'),
    ReceiptKeyword('áfa', 'HU'),
    ReceiptKeyword('afa', 'HU'),
    ReceiptKeyword('dph', 'CS/SK'),
    ReceiptKeyword('ptu', 'PL'),
    ReceiptKeyword('vat', 'PL'),
    ReceiptKeyword('tva', 'FR'),
    ReceiptKeyword('btw', 'NL'),
    ReceiptKeyword('moms', 'DK/SE'),
    ReceiptKeyword('mva', 'NO'),
  ];

  /// Hinweis auf eine im Gesamtbetrag enthaltene Steuer („darin enthalten“).
  static const includedTax = [
    ReceiptKeyword('heraf moms', 'DK'),
    ReceiptKeyword('varav moms', 'SE'),
    ReceiptKeyword('herav mva', 'NO'),
    ReceiptKeyword('inkl', 'DE/DK'),
    ReceiptKeyword('enthalten', 'DE'),
    ReceiptKeyword('incl', 'EN/NL'),
    ReceiptKeyword('included', 'EN'),
    ReceiptKeyword('moms', 'DK/SE'),
    ReceiptKeyword('znesek ddv', 'SL'),
    ReceiptKeyword('iznos pdv', 'HR'),
  ];

  /// Belegdatum (Ausstellungsdatum).
  static const date = [
    ReceiptKeyword('datum', 'DE/SL/HR/NL/DK/SE/NO/CS'),
    ReceiptKeyword('ausgestellt', 'DE'),
    ReceiptKeyword('date', 'EN/FR'),
    ReceiptKeyword('izdaje', 'SL'),
    ReceiptKeyword('izdavanja', 'HR'),
    ReceiptKeyword('data', 'IT/PL'),
    ReceiptKeyword('dátum', 'HU/SK'),
    ReceiptKeyword('kelt', 'HU'),
    ReceiptKeyword('vystavení', 'CS'),
    ReceiptKeyword('vystaveni', 'CS'),
    ReceiptKeyword('fecha', 'ES'),
    ReceiptKeyword('dato', 'DK/NO'),
  ];

  /// Datumsangaben, die nicht das Belegdatum sind (fällig, gültig bis …).
  static const notIssueDate = [
    ReceiptKeyword('fällig', 'DE'),
    ReceiptKeyword('faellig', 'DE'),
    ReceiptKeyword('zahlbar bis', 'DE'),
    ReceiptKeyword('gültig', 'DE'),
    ReceiptKeyword('mhd', 'DE'),
    ReceiptKeyword('lieferzeitraum', 'DE'),
    ReceiptKeyword('leistungszeitraum', 'DE'),
    ReceiptKeyword('due', 'EN'),
    ReceiptKeyword('valid', 'EN'),
    ReceiptKeyword('velja do', 'SL'),
    ReceiptKeyword('veljavnost', 'SL'),
    ReceiptKeyword('rok plačila', 'SL'),
    ReceiptKeyword('scadenza', 'IT'),
    ReceiptKeyword('határidő', 'HU'),
    ReceiptKeyword('splatnost', 'CS/SK'),
    ReceiptKeyword('termin płatności', 'PL'),
    ReceiptKeyword('échéance', 'FR'),
    ReceiptKeyword('vencimiento', 'ES'),
    ReceiptKeyword('vervaldatum', 'NL'),
    ReceiptKeyword('forfald', 'DK/NO'),
    ReceiptKeyword('förfallo', 'SE'),
  ];

  /// Bezeichnungen der Rechnungs- bzw. Belegnummer. Gewicht 85: Rechnung,
  /// 70: Bon/Beleg.
  static const invoiceNumber = [
    ReceiptKeyword('rechnungsnummer', 'DE', weight: 85),
    ReceiptKeyword('rechnungsnr', 'DE', weight: 85),
    ReceiptKeyword('rechnung nr', 'DE', weight: 85),
    ReceiptKeyword('re-nr', 'DE', weight: 85),
    ReceiptKeyword('re.nr', 'DE', weight: 85),
    ReceiptKeyword('re nr', 'DE', weight: 85),
    ReceiptKeyword('belegnummer', 'DE', weight: 70),
    ReceiptKeyword('beleg-nr', 'DE', weight: 70),
    ReceiptKeyword('belegnr', 'DE', weight: 70),
    ReceiptKeyword('bon-nr', 'DE', weight: 70),
    ReceiptKeyword('bonnr', 'DE', weight: 70),
    ReceiptKeyword('quittung nr', 'DE', weight: 70),
    ReceiptKeyword('invoice number', 'EN', weight: 85),
    ReceiptKeyword('invoice no', 'EN', weight: 85),
    ReceiptKeyword('invoice nr', 'EN', weight: 85),
    ReceiptKeyword('invoice #', 'EN', weight: 85),
    ReceiptKeyword('receipt no', 'EN', weight: 70),
    ReceiptKeyword('št. računa', 'SL', weight: 85),
    ReceiptKeyword('st. racuna', 'SL', weight: 85),
    ReceiptKeyword('številka računa', 'SL', weight: 85),
    ReceiptKeyword('stevilka racuna', 'SL', weight: 85),
    ReceiptKeyword('račun št', 'SL', weight: 85),
    ReceiptKeyword('racun st', 'SL', weight: 85),
    ReceiptKeyword('broj računa', 'HR', weight: 85),
    ReceiptKeyword('broj racuna', 'HR', weight: 85),
    ReceiptKeyword('račun br', 'HR', weight: 85),
    ReceiptKeyword('racun br', 'HR', weight: 85),
    ReceiptKeyword('fattura n', 'IT', weight: 85),
    ReceiptKeyword('numero fattura', 'IT', weight: 85),
    ReceiptKeyword('számla sorszáma', 'HU', weight: 85),
    ReceiptKeyword('számlaszám', 'HU', weight: 85),
    ReceiptKeyword('szamlaszam', 'HU', weight: 85),
    ReceiptKeyword('číslo faktury', 'CS/SK', weight: 85),
    ReceiptKeyword('cislo faktury', 'CS/SK', weight: 85),
    ReceiptKeyword('číslo dokladu', 'CS/SK', weight: 70),
    ReceiptKeyword('cislo dokladu', 'CS/SK', weight: 70),
    ReceiptKeyword('faktura nr', 'PL/DK/SE/NO', weight: 85),
    ReceiptKeyword('fakturanr', 'DK/SE/NO', weight: 85),
    ReceiptKeyword('fakturanummer', 'DK/SE/NO', weight: 85),
    ReceiptKeyword('paragon nr', 'PL', weight: 70),
    ReceiptKeyword('facture n', 'FR', weight: 85),
    ReceiptKeyword('n° facture', 'FR', weight: 85),
    ReceiptKeyword('factura n', 'ES', weight: 85),
    ReceiptKeyword('número de factura', 'ES', weight: 85),
    ReceiptKeyword('factuurnummer', 'NL', weight: 85),
    ReceiptKeyword('factuurnr', 'NL', weight: 85),
    ReceiptKeyword('kvitteringsnr', 'DK/NO', weight: 70),
    ReceiptKeyword('kvittonr', 'SE', weight: 70),
  ];

  static final _cache = <List<ReceiptKeyword>, RegExp>{};

  /// Regulärer Ausdruck, der irgendeinen Eintrag der Tabelle findet. Kurze
  /// Einträge (unter fünf Zeichen, z. B. „ust“, „ddv“, „ht“) nur als ganzes
  /// Wort, längere auch mit OCR-Rauschen davor („ITotal“). Ein Punkt im
  /// Eintrag darf fehlen.
  static RegExp pattern(List<ReceiptKeyword> table) => _cache.putIfAbsent(
    table,
    () => RegExp(
      '(${[for (final k in table) _entry(k.text)].join('|')})',
      unicode: true,
    ),
  );

  static String _entry(String text) => text.length < 5
      ? '(?<![\\p{L}\\d])${_escape(text)}(?![\\p{L}])'
      : _escape(text);

  static String _escape(String s) => [
    for (final c in s.split(''))
      switch (c) {
        ' ' => r'[\s.:\-]*',
        '.' => r'\.?',
        '-' => r'[\-\s.]?',
        _ => RegExp.escape(c),
      },
  ].join();

  /// Höchstes Gewicht eines Treffers in [lower] oder 0.
  static int weightIn(List<ReceiptKeyword> table, String lower) {
    var best = 0;
    for (final m in pattern(table).allMatches(lower)) {
      final hit = m.group(1)!;
      for (final k in table) {
        if (k.weight > best && pattern([k]).hasMatch(hit)) best = k.weight;
      }
    }
    return best;
  }

  static bool any(List<ReceiptKeyword> table, String lower) =>
      pattern(table).hasMatch(lower);
}
