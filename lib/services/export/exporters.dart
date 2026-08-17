import '../../core/formatting.dart';
import '../../data/repositories.dart';
import '../../domain/company_profile.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import 'csv.dart';

/// Verfügbare Exportformate.
enum ExportFormat {
  plainCsv(
    'Belegliste (CSV)',
    'Alle Belege als Tabelle – lässt sich in Excel, Numbers und jedem '
        'Buchhaltungsprogramm öffnen. Der sichere Standard, wenn unklar ist, '
        'womit die Kanzlei arbeitet.',
    'csv',
  ),
  datev(
    'DATEV-Buchungsstapel (EXTF)',
    'Importformat für DATEV-Kanzleien (Deutschland). Berater- und '
        'Mandantennummer musst du vorher von der Kanzlei erfragen.',
    'csv',
  ),
  bmd(
    'BMD-Buchungssätze (CSV)',
    'Importformat für BMD NTCS (Österreich). Die Kontonummern stimmst du '
        'am besten einmalig mit der Kanzlei ab.',
    'csv',
  ),
  vatReturn(
    'Umsatzsteuer-Zusammenfassung',
    'Bemessungsgrundlagen und Vorsteuer je Steuersatz – die Zahlen, die für '
        'die Umsatzsteuervoranmeldung gebraucht werden.',
    'csv',
  );

  const ExportFormat(this.label, this.description, this.extension);

  final String label;
  final String description;
  final String extension;
}

/// Ergebnis eines Exports: Dateiname und Inhalt, noch nicht geschrieben.
class ExportResult {
  const ExportResult({
    required this.fileName,
    required this.content,
    required this.rowCount,
  });

  final String fileName;
  final String content;
  final int rowCount;

  bool get isEmpty => rowCount == 0;
}

/// Erzeugt Exportdateien für die Steuerberatung.
///
/// Wichtig: Die Kontenzuordnung folgt SKR03 (Deutschland). Für Österreich wird
/// auf den Einheitskontenrahmen gemappt, siehe [_austrianAccount]. Beide
/// Zuordnungen sind Vorschläge – jede Kanzlei hat eigene Gewohnheiten, deshalb
/// ist die Kategorie-Kontonummer in den Einstellungen überschreibbar.
class Exporter {
  const Exporter({
    required this.profile,
    required this.receipts,
    required this.categories,
    required this.totals,
    required this.period,
  });

  final CompanyProfile profile;
  final List<Receipt> receipts;
  final List<ExpenseCategory> categories;
  final PeriodTotals totals;
  final Period period;

  ExportResult build(ExportFormat format) => switch (format) {
    ExportFormat.plainCsv => _buildPlainCsv(),
    ExportFormat.datev => _buildDatev(),
    ExportFormat.bmd => _buildBmd(),
    ExportFormat.vatReturn => _buildVatReturn(),
  };

  String _fileName(String prefix, String extension) {
    final company = profile.companyName.isEmpty
        ? 'buchhaltung'
        : profile.companyName.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '-',
          );
    final from = Fmt.isoDate(period.from);
    final to = Fmt.isoDate(period.to);
    return '${prefix}_${company}_${from}_$to.$extension';
  }

  String _categoryName(int? id) =>
      categories.where((c) => c.id == id).map((c) => c.name).firstOrNull ??
      'Nicht zugeordnet';

  String _account(int? categoryId) =>
      categories
          .where((c) => c.id == categoryId)
          .map((c) => c.datevAccount)
          .firstOrNull ??
      _fallbackAccount(categoryId);

  String _fallbackAccount(int? categoryId) => '4900';

  /// Gegenkonto nach Zahlungsart (SKR03).
  static String _contraAccount(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => '1000', // Kasse
    PaymentMethod.bank => '1200', // Bank
    PaymentMethod.card => '1200',
    PaymentMethod.other => '1360', // Geldtransit / durchlaufende Posten
  };

  /// Grobes Mapping SKR03 → österreichischer Einheitskontenrahmen.
  /// Bewusst konservativ: was nicht sicher zuzuordnen ist, landet auf dem
  /// Sammelkonto und wird von der Kanzlei umgebucht.
  static String _austrianAccount(String skr03) => switch (skr03) {
    '8400' => '4000', // Umsatzerlöse 20 %
    '8300' => '4010', // Umsatzerlöse ermäßigt
    '8500' => '4600', // Übrige Erträge
    '3400' => '5100', // Wareneinsatz
    '3100' => '5700', // Bezogene Leistungen
    '4930' => '7380', // Büromaterial
    '4920' => '7360', // Telefon
    '4670' => '7350', // Reisekosten
    '4530' => '7320', // Kfz
    '4210' => '7200', // Miete
    '4360' => '7700', // Versicherungen
    '4380' => '7750', // Beiträge
    '4945' => '7820', // Fortbildung
    '4600' => '7650', // Werbung
    '4970' => '8280', // Bankspesen
    _ => '7800', // Sonstiger Aufwand
  };

  // ---------------------------------------------------------------------------
  // Belegliste
  // ---------------------------------------------------------------------------

  ExportResult _buildPlainCsv() {
    final csv = CsvWriter();
    csv.writeRow([
      'Datum',
      'Art',
      'Beschreibung',
      'Geschäftspartner',
      'Kategorie',
      'Konto',
      'Zahlungsart',
      'Netto',
      'USt-Satz',
      'USt-Betrag',
      'Brutto',
      'Beleg vorhanden',
      'Notiz',
    ]);

    for (final receipt in receipts) {
      csv.writeRow([
        Fmt.isoDate(receipt.date),
        receipt.direction.label,
        receipt.description,
        receipt.counterparty,
        _categoryName(receipt.categoryId),
        _accountForCountry(receipt.categoryId),
        receipt.paymentMethod.label,
        csvAmount(receipt.net.cents),
        Fmt.vatRate(receipt.vatPermille),
        csvAmount(receipt.vat.cents),
        csvAmount(receipt.gross.cents),
        receipt.hasImage ? 'ja' : 'nein',
        receipt.note,
      ]);
    }

    // Summenzeile: erspart der Kanzlei das Nachrechnen und macht sofort
    // sichtbar, ob beim Import etwas verloren gegangen ist.
    csv.writeRow([]);
    csv.writeRow([
      'Summe Einnahmen',
      '',
      '',
      '',
      '',
      '',
      '',
      csvAmount(totals.incomeNet.cents),
      '',
      csvAmount(totals.incomeVat.cents),
      csvAmount(totals.incomeGross.cents),
    ]);
    csv.writeRow([
      'Summe Ausgaben',
      '',
      '',
      '',
      '',
      '',
      '',
      csvAmount(totals.expenseNet.cents),
      '',
      csvAmount(totals.expenseVat.cents),
      csvAmount(totals.expenseGross.cents),
    ]);
    csv.writeRow([
      'Ergebnis (netto)',
      '',
      '',
      '',
      '',
      '',
      '',
      csvAmount(totals.profit.cents),
    ]);

    return ExportResult(
      fileName: _fileName('belege', 'csv'),
      content: csv.build(),
      rowCount: receipts.length,
    );
  }

  String _accountForCountry(int? categoryId) {
    final skr = _account(categoryId);
    return profile.country == Country.at ? _austrianAccount(skr) : skr;
  }

  // ---------------------------------------------------------------------------
  // DATEV EXTF
  // ---------------------------------------------------------------------------

  /// DATEV-Buchungsstapel im EXTF-Format, Formatversion 700.
  ///
  /// Der Aufbau ist bewusst auf die Pflichtfelder beschränkt. Berater- und
  /// Mandantennummer kennt die App nicht – sie stehen als 0 im Header und
  /// müssen von der Kanzlei ergänzt werden. Das ist der übliche Weg: die
  /// Kanzlei ordnet den Stapel beim Import ihrem Mandanten zu.
  ExportResult _buildDatev() {
    final csv = CsvWriter();
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}000';

    // Kopfzeile 1: Metadaten des Stapels.
    csv.writeRaw(
      [
        '"EXTF"', // Kennung
        '700', // Formatversion
        '21', // Kategorie: Buchungsstapel
        '"Buchungsstapel"',
        '13', // Formatversion der Kategorie
        stamp, // Erzeugt am
        '', // Importiert (leer)
        '"RE"', // Herkunft
        '"${_datevText(profile.companyName)}"', // Exportiert von
        '""', // Importiert von
        '0', // Beraternummer – von der Kanzlei zu ergänzen
        '0', // Mandantennummer – von der Kanzlei zu ergänzen
        '${period.from.year}0101', // Beginn Wirtschaftsjahr
        '4', // Sachkontenlänge
        _datevDate(period.from),
        _datevDate(period.to),
        '"${_datevText(period.label)}"',
        '""', // Diktatkürzel
        '1', // Buchungstyp: 1 = Finanzbuchführung
        '', // Rechnungslegungszweck
        '0', // Festschreibung: 0 = nicht festgeschrieben
        '"EUR"',
        '', '', '', '', '', '', '', '', '', '', '', '', '', '',
      ].join(';'),
    );

    // Kopfzeile 2: Spaltenüberschriften.
    csv.writeRow([
      'Umsatz (ohne Soll/Haben-Kz)',
      'Soll/Haben-Kennzeichen',
      'WKZ Umsatz',
      'Kurs',
      'Basis-Umsatz',
      'WKZ Basis-Umsatz',
      'Konto',
      'Gegenkonto (ohne BU-Schlüssel)',
      'BU-Schlüssel',
      'Belegdatum',
      'Belegfeld 1',
      'Belegfeld 2',
      'Skonto',
      'Buchungstext',
    ]);

    for (final receipt in receipts) {
      // DATEV bucht immer brutto; die Steuer ergibt sich aus dem BU-Schlüssel
      // bzw. dem Automatikkonto. Das Vorzeichen steckt im Soll/Haben-Kennzeichen,
      // nicht im Betrag.
      final isIncome = receipt.direction == BookingDirection.income;
      csv.writeRow([
        csvAmount(receipt.gross.cents.abs()),
        isIncome ? 'H' : 'S',
        'EUR',
        '',
        '',
        '',
        isIncome
            ? _account(receipt.categoryId)
            : _contraAccount(receipt.paymentMethod),
        isIncome
            ? _contraAccount(receipt.paymentMethod)
            : _account(receipt.categoryId),
        '', // BU-Schlüssel: leer = Automatikkonto entscheidet
        _datevDayMonth(receipt.date),
        receipt.id?.toString() ?? '',
        '',
        '',
        _datevText(
          receipt.description.isEmpty
              ? receipt.counterparty
              : receipt.description,
        ),
      ]);
    }

    return ExportResult(
      fileName: _fileName('datev-buchungsstapel', 'csv'),
      content: csv.build(),
      rowCount: receipts.length,
    );
  }

  /// DATEV erlaubt im Buchungstext maximal 60 Zeichen und keine Semikola.
  static String _datevText(String value) {
    final cleaned = value.replaceAll(';', ',').replaceAll('"', "'").trim();
    return cleaned.length <= 60 ? cleaned : cleaned.substring(0, 60);
  }

  static String _datevDate(DateTime date) =>
      '${date.year}${_two(date.month)}${_two(date.day)}';

  /// Belegdatum im Buchungsstapel ist TTMM ohne Jahr – das Jahr steckt im Header.
  static String _datevDayMonth(DateTime date) =>
      '${_two(date.day)}${_two(date.month)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  // ---------------------------------------------------------------------------
  // BMD
  // ---------------------------------------------------------------------------

  /// Buchungssätze für BMD NTCS (Österreich).
  ///
  /// BMD ist beim Import nachsichtiger als DATEV: eine CSV mit Kopfzeile und
  /// den Feldern unten lässt sich über den generischen Importassistenten
  /// einlesen. Der Steuercode steuert die Umsatzsteuerbehandlung.
  ExportResult _buildBmd() {
    final csv = CsvWriter();
    csv.writeRow([
      'Satzart',
      'Konto',
      'Gegenkonto',
      'Belegdatum',
      'Belegnummer',
      'Buchungstext',
      'Betrag',
      'Steuercode',
      'Steuersatz',
      'Steuerbetrag',
      'Buchsymbol',
    ]);

    for (final receipt in receipts) {
      final isIncome = receipt.direction == BookingDirection.income;
      final account = _austrianAccount(_account(receipt.categoryId));
      csv.writeRow([
        '0', // Buchungszeile
        isIncome ? _contraAccount(receipt.paymentMethod) : account,
        isIncome ? account : _contraAccount(receipt.paymentMethod),
        Fmt.isoDate(receipt.date),
        receipt.id?.toString() ?? '',
        _datevText(
          receipt.description.isEmpty
              ? receipt.counterparty
              : receipt.description,
        ),
        csvAmount(receipt.gross.cents.abs()),
        _bmdTaxCode(receipt),
        Fmt.vatRate(receipt.vatPermille),
        csvAmount(receipt.vat.cents.abs()),
        receipt.paymentMethod == PaymentMethod.cash ? 'KA' : 'BK',
      ]);
    }

    return ExportResult(
      fileName: _fileName('bmd-buchungssaetze', 'csv'),
      content: csv.build(),
      rowCount: receipts.length,
    );
  }

  /// Steuercodes nach BMD-Standard. Bei 0 % wird zwischen echter Steuerfreiheit
  /// und Kleinunternehmerbefreiung nicht unterschieden – beides ist für die
  /// Kanzlei am Code 0 erkennbar und wird dort feinjustiert.
  static String _bmdTaxCode(Receipt receipt) {
    if (receipt.vatPermille == 0) return '0';
    final isIncome = receipt.direction == BookingDirection.income;
    return switch (receipt.vatPermille) {
      200 => isIncome ? '1' : '11',
      130 => isIncome ? '3' : '13',
      100 => isIncome ? '2' : '12',
      _ => '0',
    };
  }

  // ---------------------------------------------------------------------------
  // Umsatzsteuer-Zusammenfassung
  // ---------------------------------------------------------------------------

  /// Die Zahlen, die in die Umsatzsteuervoranmeldung wandern.
  ///
  /// Bewusst keine automatische Befüllung eines Formulars: die UVA ist eine
  /// Steuererklärung, und die Verantwortung dafür bleibt beim Unternehmer bzw.
  /// seiner Kanzlei. Die App liefert die Bemessungsgrundlagen, nicht die Meldung.
  ExportResult _buildVatReturn() {
    final csv = CsvWriter();
    final tax = profile.taxProfile;

    csv.writeRow(['Umsatzsteuer-Zusammenfassung']);
    csv.writeRow(['Unternehmen', profile.companyName]);
    csv.writeRow(['Land', profile.country.label]);
    csv.writeRow([tax.taxNumberLabel, profile.taxNumber]);
    csv.writeRow([tax.vatIdLabel, profile.vatId]);
    csv.writeRow(['Zeitraum', period.label]);
    csv.writeRow(['Von', Fmt.isoDate(period.from)]);
    csv.writeRow(['Bis', Fmt.isoDate(period.to)]);
    csv.writeRow([]);

    if (profile.isSmallBusiness) {
      csv.writeRow([
        'Hinweis',
        'Kleinunternehmer nach ${tax.smallBusinessLegalRef} – '
            'keine Umsatzsteuer ausgewiesen, kein Vorsteuerabzug.',
      ]);
      csv.writeRow([]);
    }

    csv.writeRow(['Steuerpflichtige Umsätze']);
    csv.writeRow(['Steuersatz', 'Bemessungsgrundlage', 'Umsatzsteuer']);
    final incomeRates = totals.incomeNetByRate.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final permille in incomeRates) {
      final net = totals.incomeNetByRate[permille] ?? const Money.zero();
      final vat = Money((net.cents * permille / 1000).round());
      csv.writeRow([
        Fmt.vatRate(permille),
        csvAmount(net.cents),
        csvAmount(vat.cents),
      ]);
    }
    csv.writeRow([
      'Summe',
      csvAmount(totals.incomeNet.cents),
      csvAmount(totals.incomeVat.cents),
    ]);
    csv.writeRow([]);

    csv.writeRow(['Vorsteuer']);
    csv.writeRow(['Steuersatz', 'Vorsteuerbetrag']);
    final vatRates = totals.inputVatByRate.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final permille in vatRates) {
      csv.writeRow([
        Fmt.vatRate(permille),
        csvAmount(
          (totals.inputVatByRate[permille] ?? const Money.zero()).cents,
        ),
      ]);
    }
    csv.writeRow(['Summe Vorsteuer', csvAmount(totals.expenseVat.cents)]);
    csv.writeRow([]);

    final payable = totals.vatPayable;
    csv.writeRow([
      payable.isNegative ? 'Guthaben' : 'Zahllast',
      csvAmount(payable.cents.abs()),
    ]);
    csv.writeRow([]);
    csv.writeRow(['Einnahmen netto', csvAmount(totals.incomeNet.cents)]);
    csv.writeRow(['Ausgaben netto', csvAmount(totals.expenseNet.cents)]);
    csv.writeRow(['Ergebnis netto', csvAmount(totals.profit.cents)]);
    csv.writeRow([]);
    csv.writeRow([
      'Hinweis',
      'Erstellt mit der App Buchhaltung. Die Zahlen ersetzen keine steuerliche '
          'Beratung und keine geprüfte Umsatzsteuervoranmeldung.',
    ]);

    return ExportResult(
      fileName: _fileName('umsatzsteuer', 'csv'),
      content: csv.build(),
      rowCount: incomeRates.length + vatRates.length,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
