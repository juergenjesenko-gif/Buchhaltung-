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
import '../dunning_service.dart';
import '../invoice_numbering.dart';
import '../levies/levy_estimator.dart';
import '../receipt_vat_split.dart';
import '../vat_calculator.dart';
import 'demo_dataset.dart';
import 'demo_receipt_image.dart';

/// Deutsche Musterfirma der Demo (Rückmeldung Auftraggeber zu 0.30.0).
///
/// Alles erfunden: „Muster Handel“, Einzelunternehmen in Musterstadt (Bayern),
/// **Kleinunternehmerin nach § 19 UStG** (Fassung ab 2025) mit rund
/// 15.000 € Umsatz im laufenden Jahr – die Grenzwertampel misst an der
/// 25.000-€-Vorjahresgrenze und zeigt rund 60 %. Gewinnermittlung EÜR
/// (§ 4 Abs 3 EStG), Gewerbesteuer in „Abgaben & Rücklagen“ (Freibetrag
/// 24.500 €, § 11 Abs 1 GewStG), deutsche Fristen aus dem `TaxProfile`.
/// Steuersätze der Eingangsbelege: 19 % und 7 % (§ 12 UStG DE); als
/// Kleinunternehmerin ohne Vorsteuerabzug (§ 19 Abs 1 Satz 4 UStG).
/// Händler, Personen und Nummern sind Platzhalter (P-R56).
class DemoDatasetDe {
  DemoDatasetDe._();

  static const companyName = 'Muster Handel';

  /// Erfundene Händler; der Markentest prüft sie mit (P-R56).
  static const merchants = [
    'Tankstelle Am Ring',
    'Baumarkt Huber',
    'Gasthaus Zur Linde',
    'Bürowelt Mustermann',
    'Druckerei Feder & Co',
    'Netz & Telefon Muster',
    'Wareneinkauf Muster GmbH',
    'Bank Muster',
    'Krankenkasse Muster',
    'Hausverwaltung Muster',
  ];

  /// Belege ohne Rechnungszahlungen.
  static const receiptCount = 17;

  static Future<void> seed(
    Database db, {
    required DateTime today,
    required DemoImageWriter writeImage,
  }) async {
    final repos = Repositories(db);
    final now = DateTime(today.year, today.month, today.day);
    DateTime ago(int days) => now.subtract(Duration(days: days));

    await repos.consents.accept(LegalText.all, now: now);

    final profile = CompanyProfile(
      companyName: companyName,
      country: Country.de,
      ownerName: 'Mia Muster',
      street: 'Musterweg 7',
      postalCode: '80000',
      city: 'Musterstadt',
      email: 'post@muster-handel.example',
      phone: '+49 89 0000000',
      taxNumber: '000/000/00000',
      // Kleinunternehmerin nach § 19 UStG: keine USt-IdNr nötig.
      isSmallBusiness: true,
      iban: 'DE00 0000 0000 0000 0000 00',
      bic: 'MUSTDEMM',
      bankName: 'Musterbank',
      invoiceNumberPattern: InvoiceNumbering.defaultPattern,
      trackingStart: DateTime(now.year - 1, 1, 1),
      foundingYear: now.year - 3,
      fiscalYearConfirmed: true,
      federalState: 'BY',
      defaultSkontoDays: 7,
      defaultSkontoPermille: 20,
    );
    await repos.company.save(profile);

    final categories = {
      for (final c in await repos.categories.all()) c.name: c.id!,
    };

    final kita = await repos.customers.save(
      const Customer(
        name: 'Beispiel Werkstatt GmbH',
        contactPerson: 'Frau Beispiel',
        street: 'Industriestraße 12',
        postalCode: '90000',
        city: 'Beispielhausen',
        email: 'einkauf@beispiel-werkstatt.example',
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
      kita: await repos.customers.byId(kita),
      jonas: await repos.customers.byId(jonas),
    };

    await repos.articles.save(
      const Article(
        number: 'A-001',
        name: 'Beratungsstunde',
        unit: 'Std',
        unitPrice: Money(8000),
        vatPermille: 0,
      ),
    );
    await repos.articles.save(
      const Article(
        number: 'A-002',
        name: 'Montageset Regal',
        unitPrice: Money(4500),
        vatPermille: 0,
      ),
    );

    var imageNo = 0;
    Future<int> receipt({
      required int daysAgo,
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
          date: ago(daysAgo),
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
      daysAgo: 3,
      merchant: 'Tankstelle Am Ring',
      description: 'Diesel Lieferwagen 40,2 l',
      category: 'Kfz-Kosten',
      parts: [(190, 7036)],
    );
    await receipt(
      daysAgo: 31,
      merchant: 'Tankstelle Am Ring',
      description: 'Diesel Lieferwagen 37,9 l',
      category: 'Kfz-Kosten',
      parts: [(190, 6633)],
    );
    // Buchungsregeln (FA-20.x, Auftrag 2026-10-20): Privat-PKW zu 30 %
    // betrieblich laut Fahrtenbuch und Büro 12 m² von 80 m² Wohnung.
    await receipt(
      daysAgo: 12,
      merchant: 'Autowerkstatt Muster',
      description: 'Service Privat-PKW',
      category: 'Kfz-Kosten',
      parts: [(190, 42000)],
    );
    await receipt(
      daysAgo: 20,
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
      daysAgo: 8,
      merchant: 'Baumarkt Huber',
      description: 'Schrauben, Dübel, Kabelbinder',
      category: 'Material und Werkzeug',
      parts: [(190, 2847)],
    );
    // Bewirtung: in Deutschland 19 % auf Speisen und Getränke im Lokal.
    await receipt(
      daysAgo: 12,
      merchant: 'Gasthaus Zur Linde',
      description: 'Geschäftsessen Beispiel Werkstatt',
      category: 'Bewirtung',
      parts: [(190, 7420)],
    );
    await receipt(
      daysAgo: 15,
      merchant: 'Bürowelt Mustermann',
      description: 'Druckerpapier und Ordner',
      category: 'Büromaterial',
      parts: [(190, 3990)],
      payment: PaymentMethod.cash,
    );
    // Fachbuch: ermäßigter Satz 7 % (§ 12 Abs 2 Nr 1 UStG DE, Anlage 2).
    await receipt(
      daysAgo: 44,
      merchant: 'Bürowelt Mustermann',
      description: 'Fachbuch Buchführung, Notizblöcke',
      category: 'Büromaterial',
      parts: [(70, 2490), (190, 1190)],
    );
    await receipt(
      daysAgo: 20,
      merchant: 'Druckerei Feder & Co',
      description: 'Visitenkarten und Flyer',
      category: 'Werbung & Marketing',
      parts: [(190, 11900)],
      payment: PaymentMethod.bank,
    );
    for (final days in [18, 48]) {
      await receipt(
        daysAgo: days,
        merchant: 'Netz & Telefon Muster',
        description: 'Mobilfunk und Internet',
        category: 'Telefon & Internet',
        parts: [(190, 4999)],
        payment: PaymentMethod.bank,
      );
    }
    await receipt(
      daysAgo: 52,
      merchant: 'Wareneinkauf Muster GmbH',
      description: 'Regalböden 10 Stk',
      category: 'Wareneinkauf',
      parts: [(190, 47600)],
      payment: PaymentMethod.bank,
    );
    await receipt(
      daysAgo: 22,
      merchant: 'Bank Muster',
      description: 'Kontoführung',
      category: 'Bankspesen',
      parts: [(0, 990)],
      payment: PaymentMethod.bank,
      image: false,
    );
    // Barverkäufe ohne Rechnung; als Kleinunternehmerin ohne USt.
    await receipt(
      daysAgo: 5,
      merchant: 'Barverkauf',
      description: 'Montageset Regal, Laufkundschaft',
      category: 'Umsatzerlöse',
      parts: [(0, 9000)],
      payment: PaymentMethod.cash,
      direction: BookingDirection.income,
      image: false,
    );
    await receipt(
      daysAgo: 36,
      merchant: 'Barverkauf',
      description: 'Montagesets Regal, Markttag',
      category: 'Umsatzerlöse',
      parts: [(0, 58500)],
      payment: PaymentMethod.cash,
      direction: BookingDirection.income,
      image: false,
    );
    // Abgaben & Rücklagen: Krankenversicherung (Sonderausgabe) und
    // ESt-Vorauszahlung laut Bescheid (§ 37 EStG, Quartalsende).
    await receipt(
      daysAgo: 25,
      merchant: 'Krankenkasse Muster',
      description: 'Kranken- und Pflegeversicherung',
      category: 'Sozialversicherung',
      parts: [(0, 24500)],
      payment: PaymentMethod.bank,
      image: false,
    );
    await receipt(
      daysAgo: 60,
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
      required int daysAgo,
      required List<InvoiceItem> items,
      int termDays = 14,
    }) {
      final issued = ago(daysAgo);
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

    // Bezahlt: zusammen mit den Barverkäufen rund 15.000 € Umsatz.
    final paid0 = await invoice(
      customerId: kita,
      daysAgo: 130,
      items: [item('Lagereinrichtung Halle', 1000, 450000)],
    );
    await repos.invoices.markPaid(paid0, ago(120));
    final paid1 = await invoice(
      customerId: kita,
      daysAgo: 95,
      items: [item('Lagerregal Montage', 3000, 110000)],
    );
    await repos.invoices.markPaid(paid1, ago(85));
    final paid2 = await invoice(
      customerId: kita,
      daysAgo: 57,
      items: [
        item('Regalsystem Werkstatt', 1000, 380000),
        item('Beratungsstunde', 10000, 8000, unit: 'Std'),
      ],
    );
    await repos.invoices.markPaid(paid2, ago(49));
    final paid3 = await invoice(
      customerId: jonas,
      daysAgo: 27,
      items: [item('Montageset Regal', 4000, 4500)],
    );
    await repos.invoices.markPaid(paid3, ago(20));
    // Offen, noch nicht fällig.
    await invoice(
      customerId: kita,
      daysAgo: 4,
      items: [item('Beratungsstunde', 6000, 8000, unit: 'Std')],
      termDays: 30,
    );
    // Überfällig mit Zahlungserinnerung.
    final overdue = await invoice(
      customerId: jonas,
      daysAgo: 40,
      items: [item('Wandregal mit Montage', 1000, 68000)],
    );
    final overdueInvoice = await repos.invoices.byId(overdue);
    final draft = DunningService.compose(
      invoice: overdueInvoice!,
      previous: const [],
      rules: profile.taxProfile.dunning,
      business: false,
      issuedOn: ago(12),
      newDueDate: ago(2),
      fee: const Money.zero(),
      withInterest: false,
      withFlatFee: false,
    );
    await repos.dunning.insert(draft.notice);
    // Storno mit Stornorechnung.
    final wrong = await invoice(
      customerId: jonas,
      daysAgo: 16,
      items: [item('Montageset Regal', 6000, 4500)],
    );
    await repos.invoices.cancelWithInvoice(
      wrong,
      reason: 'Falsche Menge berechnet',
      date: ago(15),
      assignNumber: (s) => number(s, ago(15)),
    );

    await repos.offers.save(
      Offer(
        number: 'AN-${now.year}-0001',
        issueDate: ago(6),
        validUntil: ago(6).add(const Duration(days: 30)),
        customerId: kita,
        status: OfferStatus.sent,
        items: [item('Lagerregal Montage', 2000, 110000)],
      ),
    );

    await repos.contracts.save(
      Contract(
        type: ContractType.rent,
        title: 'Mietvertrag Lagerraum',
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
