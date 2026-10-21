import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/repositories.dart';
import '../../domain/booking_rule.dart';
import '../../domain/article.dart';
import '../../domain/company_profile.dart';
import '../../domain/contract.dart';
import '../../domain/country.dart';
import '../../domain/customer.dart';
import '../../domain/invoice.dart';
import '../../domain/legal_texts.dart';
import '../../domain/money.dart';
import '../../domain/offer.dart';
import '../../domain/receipt.dart';
import '../invoice_numbering.dart';
import '../levies/levy_estimator.dart';
import '../receipt_vat_split.dart';
import '../vat_calculator.dart';
import 'demo_dataset.dart';
import 'demo_receipt_image.dart';

/// Deutsche Musterfirma der Demo (Rückmeldung Auftraggeber zu 0.30.0,
/// Store-Screenshots 2026-10-21).
///
/// Alles erfunden: „Mein Unternehmen“, Einzelunternehmen in Musterstadt (Bayern),
/// Grafikdesign, Fotografie und Coaching. **Kleinunternehmerin nach § 19
/// UStG** (Fassung ab 2025): Vorjahresumsatz 22.000 € (unter 25.000 €,
/// § 19 Abs 1 Satz 1 UStG), laufendes Jahr genau 63.000 € – die
/// Grenzwertanzeige steht damit bei 63 % der 100.000-€-Grenze des laufenden
/// Jahres. Einnahmen übersteigen die Ausgaben im Monat, im Quartal und im Jahr
/// deutlich; alle Rechnungen bis auf eine noch nicht fällige sind bezahlt,
/// keine Mahnung.
///
/// Datumslogik, damit das an jedem Tag des Jahres stimmt:
/// - Die Erfassung beginnt am 1. Jänner des laufenden Jahres; der
///   Vorjahresumsatz steht als Eröffnungswert (22.000 €) in der Datenbank.
/// - Alle Buchungen liegen im laufenden Jahr. Ein Abstand von bis zu 150
///   Tagen wird gestaucht, wenn seit Neujahr weniger Tage vergangen sind
///   (`past`); im Jänner rücken die Buchungen also zusammen, die Summe bleibt
///   63.000 €.
/// - Buchungen „des Monats“ (`thisMonth`) liegen nie vor dem Monatsersten.
///   Allein die Monatseinnahmen (6.250 €) übersteigen alle Ausgaben des
///   Datensatzes (rund 1.700 €), daher ist jeder Zeitraum klar positiv.
///
/// Gewinnermittlung EÜR (§ 4 Abs 3 EStG), Gewerbesteuer in „Abgaben &
/// Rücklagen“ (Freibetrag 24.500 €, § 11 Abs 1 GewStG), deutsche Fristen aus
/// dem `TaxProfile`. Steuersätze der Eingangsbelege: 19 % und 7 % (§ 12 UStG
/// DE); als Kleinunternehmerin ohne Vorsteuerabzug (§ 19 Abs 1 Satz 4 UStG).
/// Händler, Personen und Nummern sind Platzhalter (P-R56).
class DemoDatasetDe {
  DemoDatasetDe._();

  static const companyName = 'Mein Unternehmen';

  /// Erfundene Händler; der Markentest prüft sie mit (P-R56).
  static const merchants = [
    'Tankstelle Am Ring',
    'Fotofachhandel Blende 8',
    'Gasthaus Zur Linde',
    'Bürowelt Mustermann',
    'Druckerei Feder & Co',
    'Netz & Telefon Muster',
    'Fotolabor Silberkorn',
    'Bank Muster',
    'Krankenkasse Muster',
    'Hausverwaltung Muster',
  ];

  /// Belege ohne Rechnungszahlungen.
  static const receiptCount = 17;

  /// Umsatz des Vorjahres (Eröffnungswert), unter 25.000 € (§ 19 Abs 1
  /// Satz 1 UStG), damit die Kleinunternehmerregelung gilt.
  static const previousYearTurnover = Money(2200000);

  /// Umsatz des laufenden Jahres: 63 % der 100.000-€-Grenze
  /// (§ 19 Abs 1 Satz 1 UStG, Fassung ab 2025).
  static const currentYearTurnover = Money(6300000);

  static Future<void> seed(
    Database db, {
    required DateTime today,
    required DemoImageWriter writeImage,
  }) async {
    final repos = Repositories(db);
    final now = DateTime(today.year, today.month, today.day);
    // Kalendertage statt Stunden: robust gegen die Zeitumstellung.
    DateTime ago(int days) => DateTime(now.year, now.month, now.day - days);
    // Stauchung in das laufende Jahr (siehe Klassenkommentar).
    final sinceNewYear = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(now.year)).inDays;
    DateTime past(int days) =>
        ago(sinceNewYear >= 150 ? days : days * sinceNewYear ~/ 150);
    // Nie vor dem Monatsersten.
    DateTime thisMonth(int days) =>
        ago(days < now.day - 1 ? days : now.day - 1);

    await repos.consents.accept(LegalText.all, now: now);

    final profile = CompanyProfile(
      companyName: companyName,
      country: Country.de,
      ownerName: 'Mia Muster',
      street: 'Musterweg 7',
      postalCode: '80000',
      city: 'Musterstadt',
      email: 'studio@muster-handel.example',
      phone: '+49 89 0000000',
      taxNumber: '000/000/00000',
      // Kleinunternehmerin nach § 19 UStG: keine USt-IdNr nötig.
      isSmallBusiness: true,
      iban: 'DE00 0000 0000 0000 0000 00',
      bic: 'MUSTDEMM',
      bankName: 'Musterbank',
      invoiceNumberPattern: InvoiceNumbering.defaultPattern,
      trackingStart: DateTime(now.year, 1, 1),
      foundingYear: now.year - 3,
      fiscalYearConfirmed: true,
      federalState: 'BY',
      defaultSkontoDays: 7,
      defaultSkontoPermille: 20,
    );
    await repos.company.save(profile);
    await repos.openingTurnover.save(now.year - 1, previousYearTurnover);

    final categories = {
      for (final c in await repos.categories.all()) c.name: c.id!,
    };

    final bakery = await repos.customers.save(
      const Customer(
        name: 'Bäckerei Sonnenkorn GmbH',
        contactPerson: 'Frau Korn',
        street: 'Mühlenstraße 12',
        postalCode: '90000',
        city: 'Beispielhausen',
        email: 'marketing@sonnenkorn.example',
        isBusiness: true,
      ),
    );
    final jonas = await repos.customers.save(
      const Customer(
        name: 'Jonas Probe',
        street: 'Lindenallee 4',
        postalCode: '80001',
        city: 'Musterstadt',
        email: 'jonas.probe@example.com',
      ),
    );
    final customers = {
      bakery: await repos.customers.byId(bakery),
      jonas: await repos.customers.byId(jonas),
    };

    await repos.articles.save(
      const Article(
        number: 'A-001',
        name: 'Designstunde',
        unit: 'Std',
        unitPrice: Money(8500),
        vatPermille: 0,
      ),
    );
    await repos.articles.save(
      const Article(
        number: 'A-002',
        name: 'Fotoshooting halbtags',
        unitPrice: Money(45000),
        vatPermille: 0,
      ),
    );

    var imageNo = 0;
    Future<int> receipt({
      required DateTime date,
      required String merchant,
      required String description,
      required String category,
      required List<(int permille, int grossCents)> parts,
      PaymentMethod payment = PaymentMethod.card,
      BookingDirection direction = BookingDirection.expense,
      bool image = true,
    }) async {
      final vatParts = [
        for (final (permille, gross) in parts)
          (permille: permille, gross: Money(gross)),
      ];
      final vatLines = parts.length > 1
          ? ReceiptVatSplit.lines(vatParts)
          : const <ReceiptVatLine>[];
      final split = parts.length > 1
          ? null
          : VatCalculator.fromGross(Money(parts.single.$2), parts.single.$1);
      final head = parts.length > 1 ? ReceiptVatSplit.header(vatLines) : null;
      final gross = head?.gross ?? split!.gross;
      final pages = <String>[];
      if (image) {
        pages.add(
          await writeImage(
            'demo_de_${(imageNo++).toString().padLeft(2, '0')}.png',
            DemoReceiptImage.render(
              title: merchant,
              lines: [
                (description, _amount(gross)),
                for (final (permille, g) in parts)
                  ('MwSt ${permille ~/ 10} % in ${_amount(Money(g))}', ''),
              ],
              total: _amount(gross),
            ),
          ),
        );
      }
      return repos.receipts.save(
        Receipt(
          date: date,
          direction: direction,
          description: description,
          counterparty: merchant,
          net: head?.net ?? split!.net,
          vat: head?.vat ?? split!.vat,
          gross: gross,
          vatPermille: head?.permille ?? split!.permille,
          vatLines: vatLines,
          categoryId: categories[category],
          paymentMethod: payment,
          documentNumber: 'D-${1000 + imageNo}',
        ),
        pages: pages,
      );
    }

    await receipt(
      date: thisMonth(3),
      merchant: 'Tankstelle Am Ring',
      description: 'Benzin 38,4 l',
      category: 'Kfz-Kosten',
      parts: [(190, 7036)],
    );
    await receipt(
      date: past(31),
      merchant: 'Tankstelle Am Ring',
      description: 'Benzin 36,1 l',
      category: 'Kfz-Kosten',
      parts: [(190, 6633)],
    );
    // Buchungsregeln (FA-20.x, Auftrag 2026-10-20): Privat-PKW zu 30 %
    // betrieblich laut Fahrtenbuch und Büro 12 m² von 80 m² Wohnung.
    await receipt(
      date: past(12),
      merchant: 'Autowerkstatt Muster',
      description: 'Service Privat-PKW',
      category: 'Kfz-Kosten',
      parts: [(190, 28000)],
    );
    await receipt(
      date: past(20),
      merchant: 'Energie Muster',
      description: 'Strom Wohnung (mit Büro)',
      category: 'Miete & Betriebskosten',
      parts: [(190, 9600)],
      payment: PaymentMethod.bank,
    );
    await repos.bookingRules.save(
      BookingRule(
        name: 'PKW',
        categoryIds: {categories['Kfz-Kosten']!},
        supplier: 'Autowerkstatt Muster',
        businessPermille: 300,
        basis: BookingRuleBasis.logbook,
        basisPartMilli: 3000 * 1000,
        basisTotalMilli: 10000 * 1000,
        validFrom: DateTime(now.year - 1, 1, 1),
        comment: 'Privat-PKW, betriebliche Fahrten laut Fahrtenbuch.',
      ),
    );
    await repos.bookingRules.save(
      BookingRule(
        name: 'Büro',
        categoryIds: {categories['Miete & Betriebskosten']!},
        supplier: 'Energie Muster',
        businessPermille: 150,
        basis: BookingRuleBasis.area,
        basisPartMilli: 12 * 1000,
        basisTotalMilli: 80 * 1000,
        validFrom: DateTime(now.year - 1, 1, 1),
        comment: 'Abgeschlossener Büroraum, ausschließlich betrieblich.',
      ),
    );
    await receipt(
      date: thisMonth(8),
      merchant: 'Fotofachhandel Blende 8',
      description: 'Speicherkarten 2 Stk',
      category: 'Material und Werkzeug',
      parts: [(190, 7998)],
    );
    // Bewirtung: in Deutschland 19 % auf Speisen und Getränke im Lokal.
    await receipt(
      date: past(12),
      merchant: 'Gasthaus Zur Linde',
      description: 'Geschäftsessen Bäckerei Sonnenkorn',
      category: 'Bewirtung',
      parts: [(190, 7420)],
    );
    await receipt(
      date: past(15),
      merchant: 'Bürowelt Mustermann',
      description: 'Druckerpapier und Ordner',
      category: 'Büromaterial',
      parts: [(190, 3990)],
      payment: PaymentMethod.cash,
    );
    // Fachbuch: ermäßigter Satz 7 % (§ 12 Abs 2 Nr 1 UStG DE, Anlage 2).
    await receipt(
      date: past(44),
      merchant: 'Bürowelt Mustermann',
      description: 'Fachbuch Typografie, Skizzenblöcke',
      category: 'Büromaterial',
      parts: [(70, 2490), (190, 1190)],
    );
    await receipt(
      date: past(20),
      merchant: 'Druckerei Feder & Co',
      description: 'Visitenkarten und Mappen',
      category: 'Werbung & Marketing',
      parts: [(190, 11900)],
      payment: PaymentMethod.bank,
    );
    for (final days in [18, 48]) {
      await receipt(
        date: past(days),
        merchant: 'Netz & Telefon Muster',
        description: 'Mobilfunk und Internet',
        category: 'Telefon & Internet',
        parts: [(190, 4999)],
        payment: PaymentMethod.bank,
      );
    }
    await receipt(
      date: past(52),
      merchant: 'Fotolabor Silberkorn',
      description: 'Fineart-Abzüge Kundenauftrag',
      category: 'Wareneinkauf',
      parts: [(190, 18900)],
      payment: PaymentMethod.bank,
    );
    await receipt(
      date: past(22),
      merchant: 'Bank Muster',
      description: 'Kontoführung',
      category: 'Bankspesen',
      parts: [(0, 990)],
      payment: PaymentMethod.bank,
      image: false,
    );
    // Einnahmen ohne Rechnung; als Kleinunternehmerin ohne USt.
    await receipt(
      date: thisMonth(5),
      merchant: 'Barzahlung',
      description: 'Passfotos und Bewerbungsfotos',
      category: 'Umsatzerlöse',
      parts: [(0, 45000)],
      payment: PaymentMethod.cash,
      direction: BookingDirection.income,
      image: false,
    );
    await receipt(
      date: past(36),
      merchant: 'Barzahlung',
      description: 'Porträtshooting Familie',
      category: 'Umsatzerlöse',
      parts: [(0, 120000)],
      payment: PaymentMethod.cash,
      direction: BookingDirection.income,
      image: false,
    );
    // Abgaben & Rücklagen: Krankenversicherung (Sonderausgabe) und
    // ESt-Vorauszahlung laut Bescheid (§ 37 EStG, Quartalsende).
    await receipt(
      date: past(25),
      merchant: 'Krankenkasse Muster',
      description: 'Kranken- und Pflegeversicherung',
      category: 'Sozialversicherung',
      parts: [(0, 24500)],
      payment: PaymentMethod.bank,
      image: false,
    );
    await receipt(
      date: past(60),
      merchant: 'Finanzamt Musterstadt',
      description: 'Einkommensteuer-Vorauszahlung',
      category: 'Einkommensteuer-Vorauszahlung',
      parts: [(0, 30000)],
      payment: PaymentMethod.bank,
      image: false,
    );
    await repos.levySettings.save(
      const LevySettings(
        incomeTaxPrepaymentQuarter: Money(30000),
        healthInsuranceMonthly: Money(24500),
        // Hebesatz Musterstadt (erfunden, Spanne der Gemeinden).
        tradeTaxMultiplierPercent: 400,
      ),
    );

    String number(int sequence, DateTime date) => InvoiceNumbering.format(
      pattern: profile.invoiceNumberPattern,
      sequence: sequence,
      date: date,
    );
    Future<int> invoice({
      required int customerId,
      required DateTime issued,
      required List<InvoiceItem> items,
      int termDays = 14,
    }) {
      return repos.invoices.save(
        Invoice(
          number: '',
          issueDate: issued,
          deliveryDate: issued,
          dueDate: issued.add(Duration(days: termDays)),
          customerId: customerId,
          items: items,
          status: InvoiceStatus.issued,
          // Ohne Umsatzsteuer, Hinweis „Steuerbefreiung nach § 19 UStG“.
          isSmallBusiness: true,
          sellerSnapshot: jsonEncode(profile.toMap()),
          customerSnapshot: jsonEncode(customers[customerId]!.toMap()),
        ),
        assignNumber: (s) => number(s, issued),
      );
    }

    InvoiceItem item(
      String description,
      int quantityMilli,
      int unitCents, {
      String unit = 'Stk',
    }) => InvoiceItem(
      position: 0,
      description: description,
      quantityMilli: quantityMilli,
      unitPrice: Money(unitCents),
      vatPermille: 0,
      unit: unit,
    );

    // Bezahlt: zusammen mit den Barzahlungen (1.650 €) genau 63.000 € im
    // laufenden Jahr, siehe [currentYearTurnover].
    final paidInvoices = [
      (bakery, 140, 130, [item('Corporate Design komplett', 1000, 1450000)]),
      (bakery, 115, 105, [item('Imagefotos Filialen', 1000, 980000)]),
      (
        bakery,
        90,
        80,
        [
          item('Website-Gestaltung', 1000, 1070000),
          item('Designstunde', 20000, 8500, unit: 'Std'),
        ],
      ),
      (jonas, 60, 52, [item('Coaching-Paket Selbstständigkeit', 1000, 865000)]),
      (bakery, 35, 27, [item('Produktkatalog Gestaltung', 1000, 1020000)]),
    ];
    for (final (customer, issuedDays, paidDays, items) in paidInvoices) {
      final id = await invoice(
        customerId: customer,
        issued: past(issuedDays),
        items: items,
      );
      await repos.invoices.markPaid(id, past(paidDays));
    }
    final paidThisMonth = await invoice(
      customerId: bakery,
      issued: thisMonth(3),
      items: [
        item('Fotoshooting halbtags', 2000, 45000),
        item('Bildbearbeitung und Bildrechte', 1000, 490000),
      ],
    );
    await repos.invoices.markPaid(paidThisMonth, thisMonth(1));
    // Offen, noch nicht fällig – die einzige offene Rechnung, keine Mahnung.
    await invoice(
      customerId: bakery,
      issued: thisMonth(2),
      items: [item('Designstunde', 16000, 8500, unit: 'Std')],
      termDays: 30,
    );
    // Storno mit Stornorechnung.
    final wrong = await invoice(
      customerId: jonas,
      issued: past(16),
      items: [item('Fotoshooting halbtags', 2000, 45000)],
    );
    await repos.invoices.cancelWithInvoice(
      wrong,
      reason: 'Falsche Menge berechnet',
      date: past(15),
      assignNumber: (s) => number(s, past(15)),
    );

    await repos.offers.save(
      Offer(
        number: 'AN-${now.year}-0001',
        issueDate: thisMonth(6),
        validUntil: thisMonth(6).add(const Duration(days: 30)),
        customerId: bakery,
        status: OfferStatus.sent,
        items: [item('Logo-Relaunch', 1000, 240000)],
      ),
    );

    await repos.contracts.save(
      Contract(
        type: ContractType.rent,
        title: 'Mietvertrag Atelier',
        partner: 'Hausverwaltung Muster',
        startDate: DateTime(now.year - 2, 1, 1),
        endDate: now.add(const Duration(days: 80)),
        noticeValue: 3,
        noticeUnit: NoticeUnit.months,
        rate: const Money(45000),
        rhythm: PaymentRhythm.monthly,
        comment: 'Musterdaten der Demo',
      ),
    );
  }

  static String _amount(Money m) {
    final c = m.cents.abs();
    return '${m.cents < 0 ? '-' : ''}${c ~/ 100},'
        '${(c % 100).toString().padLeft(2, '0')}';
  }
}
