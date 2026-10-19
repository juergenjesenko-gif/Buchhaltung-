import 'dart:convert';
import 'dart:typed_data';

import '../levies/levy_estimator.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/repositories.dart';
import '../../domain/article.dart';
import '../../domain/company_profile.dart';
import '../../domain/contract.dart';
import '../../domain/country.dart';
import '../../domain/customer.dart';
import '../../domain/exchange_rate.dart';
import '../../domain/fixed_asset.dart';
import '../../domain/invoice.dart';
import '../../domain/legal_texts.dart';
import '../../domain/money.dart';
import '../../domain/offer.dart';
import '../../domain/receipt.dart';
import '../../domain/tax_registration.dart';
import '../dunning_service.dart';
import '../invoice_numbering.dart';
import '../receipt_vat_split.dart';
import '../vat_calculator.dart';
import 'demo_receipt_image.dart';

/// Legt ein Belegbild ab und liefert den relativen Pfad (`demo_belege/…`).
typedef DemoImageWriter = Future<String> Function(String name, Uint8List png);

/// Musterdaten der Demo (FA-13.14, Entscheidung Auftraggeber 2026-10-19).
///
/// Alles erfunden: Firma „Muster Handel e.U.“ (Wien, Regelbesteuerung, dazu
/// eine Registrierung in Deutschland), Kundschaft, Artikel, Händler
/// („Tankstelle Am Ring“, „Baumarkt Huber“ …) – keine echten Marken, keine
/// echten Personen (P-R56). UID, Steuernummer und IBAN sind sichtbar
/// ungültige Platzhalter aus Nullen. Daten liegen relativ zu [today], damit
/// die Demo immer das laufende Jahr zeigt. Die Steuersätze sind die echten
/// österreichischen (20 %, 13 %, 10 %; § 10 UStG AT) bzw. deutschen (19 %,
/// § 12 Abs 1 UStG DE); Plausibilität prüft P-S87.
class DemoDataset {
  DemoDataset._();

  static const companyName = 'Muster Handel e.U.';

  /// Erfundene Händler der Belege; Test prüft, dass keine echte Marke dabei
  /// ist (P-R56).
  static const merchants = [
    'Tankstelle Am Ring',
    'Baumarkt Huber',
    'Gasthaus Zur Linde',
    'Papeterie Sonnenschein',
    'Bürowelt Mustermann',
    'Elektro Blitz KG',
    'Café Morgenrot',
    'Druckerei Feder & Co',
    'Hotel Seeblick Zürich',
    'Versicherung Beispiel AG',
    'Netz & Telefon Muster',
    'Lager Passau Muster GmbH',
    'Wareneinkauf Muster GmbH',
    'Bank Muster',
    'Fachverlag Beispiel',
    'Hausverwaltung Muster',
  ];

  /// Ungefähre Zahl der Belege (Ausgaben und Einnahmen ohne Rechnungen).
  static const receiptCount = 28;

  static Future<void> seed(
    Database db, {
    required DateTime today,
    required DemoImageWriter writeImage,
  }) async {
    final repos = Repositories(db);
    final now = DateTime(today.year, today.month, today.day);
    DateTime ago(int days) => now.subtract(Duration(days: days));

    // Rechtstexte der Demo-Datenbank gelten als bestätigt: bestätigt hat die
    // Nutzerin sie schon in der echten Datenbank, bevor die Demo startet.
    await repos.consents.accept(LegalText.all, now: now);

    final profile = CompanyProfile(
      companyName: companyName,
      country: Country.at,
      ownerName: 'Maria Muster',
      street: 'Musterstraße 1',
      postalCode: '1010',
      city: 'Wien',
      email: 'office@muster-handel.example',
      phone: '+43 1 0000000',
      taxNumber: '00 000/0000',
      vatId: 'ATU00000000',
      // Kleinunternehmerin in AT (§ 6 Abs 1 Z 27 UStG 1994) mit deutscher
      // Registrierung für das Lager – der eigene Fall des Auftraggebers;
      // die Grenzwertampel zeigt rund 27 % (Rückmeldung 2026-10-19).
      isSmallBusiness: true,
      iban: 'AT00 0000 0000 0000 0000',
      bic: 'MUSTATWW',
      bankName: 'Musterbank',
      invoiceNumberPattern: InvoiceNumbering.defaultPattern,
      trackingStart: DateTime(now.year - 1, 1, 1),
      foundingYear: now.year - 3,
      fiscalYearConfirmed: true,
      federalState: 'W',
      hasTaxAdvisor: true,
      defaultSkontoDays: 7,
      defaultSkontoPermille: 20,
    );
    await repos.company.save(profile);

    // Zweites Steuerland (FA-18): Lager in Passau, deutsche USt-IdNr.
    final deId = await repos.registrations.save(
      TaxRegistration(
        country: Country.de,
        vatId: 'DE000000000',
        taxNumber: '000/000/00000',
        taxOffice: 'Finanzamt Musterstadt',
        interval: FilingInterval.quarterly,
        validFrom: DateTime(now.year - 1, 1, 1),
      ),
    );

    final categories = {
      for (final c in await repos.categories.all()) c.name: c.id!,
    };

    // ------------------------------------------------------------ Kunden
    final bau = await repos.customers.save(
      const Customer(
        name: 'Beispiel Bau GmbH',
        contactPerson: 'Herr Beispiel',
        street: 'Werkstraße 5',
        postalCode: '4020',
        city: 'Linz',
        vatId: 'ATU00000001',
        email: 'einkauf@beispiel-bau.example',
        isBusiness: true,
      ),
    );
    final anna = await repos.customers.save(
      const Customer(
        name: 'Anna Probe',
        street: 'Gartengasse 3',
        postalCode: '8010',
        city: 'Graz',
        email: 'anna.probe@example.com',
      ),
    );
    final nord = await repos.customers.save(
      const Customer(
        name: 'Musterfirma Nord GmbH',
        street: 'Hafenweg 9',
        postalCode: '20095',
        city: 'Hamburg',
        country: Country.de,
        vatId: 'DE000000001',
        email: 'buchhaltung@musterfirma-nord.example',
        isBusiness: true,
      ),
    );
    final customers = {
      bau: await repos.customers.byId(bau),
      anna: await repos.customers.byId(anna),
      nord: await repos.customers.byId(nord),
    };

    // ----------------------------------------------------------- Artikel
    await repos.articles.save(
      const Article(
        number: 'A-001',
        name: 'Beratungsstunde',
        unit: 'Std',
        unitPrice: Money(9000),
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
    await repos.articles.save(
      const Article(
        number: 'A-003',
        name: 'Fachbuch Ordnung im Büro',
        unitPrice: Money(2990),
        vatPermille: 0,
      ),
    );

    // ------------------------------------------------------------ Belege
    var imageNo = 0;
    Future<int> receipt({
      required int daysAgo,
      required String merchant,
      required String description,
      required String category,
      required List<(int permille, int grossCents)> parts,
      PaymentMethod payment = PaymentMethod.card,
      BookingDirection direction = BookingDirection.expense,
      String occasion = '',
      String participants = '',
      int? registrationId,
      List<(String, String)>? lines,
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
            'demo_${(imageNo++).toString().padLeft(2, '0')}.png',
            DemoReceiptImage.render(
              title: merchant,
              lines:
                  lines ??
                  [
                    (description, _amount(gross)),
                    for (final (permille, g) in parts)
                      ('USt ${permille ~/ 10} % in ${_amount(Money(g))}', ''),
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
          entertainmentOccasion: occasion,
          entertainmentParticipants: participants,
          taxRegistrationId: registrationId,
          documentNumber: 'M-${1000 + imageNo}',
        ),
        pages: pages,
      );
    }

    await receipt(
      daysAgo: 3,
      merchant: 'Tankstelle Am Ring',
      // Vorsteuer nur, weil Fiskal-LKW (§ 12 Abs 2 Z 2 lit b UStG AT;
      // PKW hätten keine, Befund Prüfinstanz Steuerberater).
      description: 'Diesel Kastenwagen (Fiskal-LKW) 42,1 l',
      category: 'Kfz-Kosten',
      parts: [(200, 7156)],
    );
    await receipt(
      daysAgo: 24,
      merchant: 'Tankstelle Am Ring',
      description: 'Diesel Kastenwagen (Fiskal-LKW) 38,4 l',
      category: 'Kfz-Kosten',
      parts: [(200, 6489)],
    );
    await receipt(
      daysAgo: 51,
      merchant: 'Tankstelle Am Ring',
      description: 'Diesel Kastenwagen (Fiskal-LKW), Scheibenreiniger',
      category: 'Kfz-Kosten',
      parts: [(200, 7890)],
    );
    await receipt(
      daysAgo: 6,
      merchant: 'Baumarkt Huber',
      description: 'Schrauben, Dübel, Kabelbinder',
      category: 'Material und Werkzeug',
      parts: [(200, 3497)],
      lines: [
        ('Schrauben 4x40 200 Stk', '12,99'),
        ('Duebel 8 mm 100 Stk', '9,49'),
        ('Kabelbinder 300 mm', '12,49'),
      ],
    );
    await receipt(
      daysAgo: 33,
      merchant: 'Baumarkt Huber',
      description: 'Akkuschrauber',
      category: 'Material und Werkzeug',
      parts: [(200, 18990)],
    );
    // Bewirtung (FA-2.60): Speisen 10 %, Getränke 20 % – ein Beleg, zwei
    // Steuersätze (§ 10 Abs 2 Z 1 lit a, Abs 1 UStG AT).
    await receipt(
      daysAgo: 9,
      merchant: 'Gasthaus Zur Linde',
      description: 'Geschäftsessen Beispiel Bau',
      category: 'Bewirtung',
      parts: [(100, 6400), (200, 2160)],
      occasion: 'Besprechung Auftrag Lagerregale',
      participants: 'Maria Muster, Herr Beispiel (Beispiel Bau GmbH)',
      lines: [
        ('2x Tagesmenue', '29,00'),
        ('1x Schnitzel', '18,50'),
        ('1x Salat', '16,50'),
        ('2x Mineral 0,5', '9,60'),
        ('2x Kaffee', '12,00'),
      ],
    );
    await receipt(
      daysAgo: 40,
      merchant: 'Café Morgenrot',
      description: 'Kundengespräch Anna Probe',
      category: 'Bewirtung',
      parts: [(100, 1180), (200, 960)],
      occasion: 'Beratung Küchenregal',
      participants: 'Maria Muster, Anna Probe',
    );
    await receipt(
      daysAgo: 12,
      merchant: 'Papeterie Sonnenschein',
      description: 'Druckerpapier, Ordner, Kuverts',
      category: 'Büromaterial',
      parts: [(200, 4380)],
      payment: PaymentMethod.cash,
    );
    await receipt(
      daysAgo: 45,
      merchant: 'Bürowelt Mustermann',
      description: 'Tonerkartusche',
      category: 'Büromaterial',
      parts: [(200, 8990)],
    );
    await receipt(
      daysAgo: 70,
      merchant: 'Bürowelt Mustermann',
      description: 'Schreibtischlampe und Kalender',
      category: 'Büromaterial',
      parts: [(200, 5470)],
      payment: PaymentMethod.cash,
    );
    await receipt(
      daysAgo: 15,
      merchant: 'Druckerei Feder & Co',
      description: 'Flyer 500 Stk',
      category: 'Werbung & Marketing',
      parts: [(200, 14400)],
      payment: PaymentMethod.bank,
    );
    await receipt(
      daysAgo: 18,
      merchant: 'Netz & Telefon Muster',
      description: 'Mobilfunk und Internet',
      category: 'Telefon & Internet',
      parts: [(200, 5990)],
      payment: PaymentMethod.bank,
    );
    await receipt(
      daysAgo: 48,
      merchant: 'Netz & Telefon Muster',
      description: 'Mobilfunk und Internet',
      category: 'Telefon & Internet',
      parts: [(200, 5990)],
      payment: PaymentMethod.bank,
    );
    await receipt(
      daysAgo: 20,
      merchant: 'Versicherung Beispiel AG',
      description: 'Betriebshaftpflicht Quartal',
      category: 'Versicherungen',
      // Versicherung: unecht steuerfrei, keine Vorsteuer (§ 6 Abs 1 Z 9
      // lit c UStG AT).
      parts: [(0, 21000)],
      payment: PaymentMethod.bank,
      image: false,
    );
    await receipt(
      daysAgo: 27,
      merchant: 'Elektro Blitz KG',
      description: 'Verlängerungskabel und Steckdosenleiste',
      category: 'Material und Werkzeug',
      parts: [(200, 3270)],
      payment: PaymentMethod.cash,
    );
    await receipt(
      daysAgo: 60,
      merchant: 'Wareneinkauf Muster GmbH',
      description: 'Regalböden 20 Stk',
      category: 'Wareneinkauf',
      parts: [(200, 96000)],
      payment: PaymentMethod.bank,
    );
    await receipt(
      daysAgo: 35,
      merchant: 'Wareneinkauf Muster GmbH',
      description: 'Montagewinkel 200 Stk',
      category: 'Wareneinkauf',
      parts: [(200, 31200)],
      payment: PaymentMethod.bank,
    );
    await receipt(
      daysAgo: 21,
      merchant: 'Bank Muster',
      description: 'Kontoführung',
      category: 'Bankspesen',
      parts: [(0, 1890)],
      payment: PaymentMethod.bank,
      image: false,
    );
    await receipt(
      daysAgo: 64,
      merchant: 'Fachverlag Beispiel',
      description: 'Fachbuch Lagerlogistik',
      category: 'Fortbildung & Fachliteratur',
      parts: [(100, 4490)],
    );
    // Barverkauf ohne Rechnung (Kassabuch).
    await receipt(
      daysAgo: 4,
      merchant: 'Barverkauf',
      description: 'Montageset Regal, Laufkundschaft',
      category: 'Umsatzerlöse',
      parts: [(0, 5400)],
      payment: PaymentMethod.cash,
      direction: BookingDirection.income,
      image: false,
    );
    await receipt(
      daysAgo: 30,
      merchant: 'Barverkauf',
      description: 'Fachbuch Ordnung im Büro, 2 Stk',
      category: 'Erlöse ermäßigter Steuersatz',
      parts: [(0, 5980)],
      payment: PaymentMethod.cash,
      direction: BookingDirection.income,
      image: false,
    );
    // Abgaben & Rücklagen (FA-19.x): SVS-Quartalsvorschreibung auf der
    // Mindestbeitragsgrundlage 2026 (551,10 € × 3: PV 305,86, KV 112,42,
    // SV 25,30, UV 38,85) und eine ESt-Vorauszahlung laut Bescheid.
    for (final days in [50, 140]) {
      await receipt(
        daysAgo: days,
        merchant: 'SVS',
        description: 'SVS-Beitrag Quartal',
        category: 'Sozialversicherung',
        parts: [(0, 48243)],
        payment: PaymentMethod.bank,
        image: false,
      );
    }
    await receipt(
      daysAgo: 65,
      merchant: 'Finanzamt Österreich',
      description: 'Einkommensteuer-Vorauszahlung',
      category: 'Einkommensteuer-Vorauszahlung',
      parts: [(0, 15000)],
      payment: PaymentMethod.bank,
      image: false,
    );
    await repos.levySettings.save(
      const LevySettings(incomeTaxPrepaymentQuarter: Money(15000)),
    );
    // Deutsche Registrierung: Lagerleistung in Passau mit 19 % (§ 12 Abs 1
    // UStG DE), Vorsteuer in der deutschen Voranmeldung. Bewusst
    // Lagerleistung, nicht Raummiete: die wäre nach § 4 Nr. 12 UStG DE
    // steuerfrei (Befund Prüfinstanz Steuerberater).
    await receipt(
      daysAgo: 25,
      merchant: 'Lager Passau Muster GmbH',
      description: 'Lagerleistung Passau (Ein- und Auslagerung)',
      category: 'Miete & Betriebskosten',
      parts: [(190, 35700)],
      payment: PaymentMethod.bank,
      registrationId: deId,
    );
    await receipt(
      daysAgo: 55,
      merchant: 'Lager Passau Muster GmbH',
      description: 'Lagerleistung Passau (Ein- und Auslagerung)',
      category: 'Miete & Betriebskosten',
      parts: [(190, 35700)],
      payment: PaymentMethod.bank,
      registrationId: deId,
    );
    // Fremdwährung (L-2.21 bis L-2.25): Hotel in Zürich, CHF 180,00. Die
    // Schweizer MWST ist keine Vorsteuer in Österreich.
    const chf = Money(18000);
    const rateMicros = 940000; // 0,94 CHF je Euro (Musterkurs)
    final eur = Money((chf.cents * 1000000 / rateMicros).round());
    final hotelMonth = ago(38);
    await repos.receipts.save(
      Receipt(
        date: hotelMonth,
        direction: BookingDirection.expense,
        description: 'Messe Zürich, 1 Nacht',
        counterparty: 'Hotel Seeblick Zürich',
        net: eur,
        vat: const Money.zero(),
        gross: eur,
        vatPermille: 0,
        currency: 'CHF',
        originalGross: chf,
        fxRateMicros: rateMicros,
        fxRateDate:
            '${hotelMonth.year}-${hotelMonth.month.toString().padLeft(2, '0')}',
        fxRateSource: ExchangeRateSource.bmfMonthly,
        categoryId: categories['Reisekosten'],
        paymentMethod: PaymentMethod.card,
        documentNumber: 'Z-4711',
      ),
      pages: [
        await writeImage(
          'demo_hotel.png',
          DemoReceiptImage.render(
            title: 'Hotel Seeblick Zurich',
            lines: const [
              ('1 Nacht Einzelzimmer', 'CHF 165,00'),
              ('Kurtaxe', 'CHF 15,00'),
            ],
            total: 'CHF 180,00',
          ),
        ),
      ],
    );
    // Anlage mit AfA (FA-15): Laptop über 3 Jahre (§ 7 Abs 1 EStG AT).
    final laptopReceipt = await receipt(
      daysAgo: 80,
      merchant: 'Elektro Blitz KG',
      description: 'Laptop 15 Zoll',
      category: 'Sonstige Ausgaben',
      parts: [(200, 143880)],
      payment: PaymentMethod.bank,
    );
    final laptop = await repos.receipts.byId(laptopReceipt);
    await repos.assets.save(
      FixedAsset(
        receiptId: laptopReceipt,
        name: 'Laptop 15 Zoll',
        acquiredOn: laptop!.date,
        cost: laptop.net,
        categoryKey: 'computer',
        usefulLifeYears: 3,
      ),
    );

    // --------------------------------------------------------- Rechnungen
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
          // Ohne Umsatzsteuer, mit Hinweis nach § 6 Abs 1 Z 27 UStG 1994.
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
      int unitCents,
      int permille, {
      String unit = 'Stk',
    }) => InvoiceItem(
      position: 0,
      description: description,
      quantityMilli: quantityMilli,
      unitPrice: Money(unitCents),
      // Kleinunternehmerin: keine Umsatzsteuer auf eigene Rechnungen.
      vatPermille: 0,
      unit: unit,
    );

    // Bezahlt.
    final paid1 = await invoice(
      customerId: bau,
      daysAgo: 58,
      items: [
        item('Lagerregal Montage', 3000, 120000, 200),
        item('Beratungsstunde', 3000, 9000, 200, unit: 'Std'),
      ],
    );
    await repos.invoices.markPaid(paid1, ago(50));
    final paid2 = await invoice(
      customerId: anna,
      daysAgo: 28,
      items: [
        item('Montageset Regal', 2000, 4500, 200),
        item('Fachbuch Ordnung im Büro', 1000, 2990, 100),
      ],
    );
    await repos.invoices.markPaid(paid2, ago(22));
    final paid3 = await invoice(
      customerId: bau,
      daysAgo: 120,
      items: [item('Lagereinrichtung Halle 2', 1000, 750000, 200)],
    );
    await repos.invoices.markPaid(paid3, ago(110));
    // Offen, noch nicht fällig. Inländische Kundin: eine Beratung an die
    // deutsche GmbH wäre Reverse Charge (§ 3a Abs 6, § 19 Abs 1 UStG AT) und
    // bekäme keine österreichische USt (Befund Prüfinstanz Steuerberater).
    await invoice(
      customerId: anna,
      daysAgo: 5,
      items: [item('Beratungsstunde', 6000, 9000, 200, unit: 'Std')],
      termDays: 30,
    );
    // Überfällig mit Zahlungserinnerung (L-3.10).
    final overdue = await invoice(
      customerId: bau,
      daysAgo: 42,
      items: [item('Regalsystem Werkstatt', 1000, 248000, 200)],
    );
    final overdueInvoice = await repos.invoices.byId(overdue);
    final draft = DunningService.compose(
      invoice: overdueInvoice!,
      previous: const [],
      rules: profile.taxProfile.dunning,
      business: true,
      issuedOn: ago(14),
      newDueDate: ago(4),
      fee: const Money.zero(),
      withInterest: false,
      withFlatFee: false,
    );
    await repos.dunning.insert(draft.notice);
    // Storno (L-3.7): falsche Menge, storniert mit Stornorechnung.
    final wrong = await invoice(
      customerId: anna,
      daysAgo: 16,
      items: [item('Montageset Regal', 5000, 4500, 200)],
    );
    await repos.invoices.cancelWithInvoice(
      wrong,
      reason: 'Falsche Menge verrechnet',
      date: ago(15),
      assignNumber: (s) => number(s, ago(15)),
    );

    // ---------------------------------------------------------- Angebote
    await repos.offers.save(
      Offer(
        number: 'AN-${now.year}-0001',
        issueDate: ago(7),
        validUntil: ago(7).add(const Duration(days: 30)),
        customerId: bau,
        status: OfferStatus.sent,
        items: [item('Lagerregal Montage', 2000, 120000, 200)],
      ),
    );
    await repos.offers.save(
      Offer(
        number: 'AN-${now.year}-0002',
        issueDate: ago(2),
        validUntil: ago(2).add(const Duration(days: 14)),
        customerId: anna,
        items: [item('Beratungsstunde', 2000, 9000, 200, unit: 'Std')],
      ),
    );

    // ---------------------------------------------------------- Verträge
    await repos.contracts.save(
      Contract(
        type: ContractType.rent,
        title: 'Mietvertrag Lager und Geschäftslokal',
        partner: 'Hausverwaltung Muster',
        startDate: DateTime(now.year - 2, 1, 1),
        // Frist in Kürze, damit die Termin-Box sie zeigt.
        endDate: now.add(const Duration(days: 75)),
        noticeValue: 3,
        noticeUnit: NoticeUnit.months,
        rate: const Money(85000),
        rhythm: PaymentRhythm.monthly,
        vatPermille: 200,
        indexation: 'VPI 2020, jährlich',
        nextIndexDate: now.add(const Duration(days: 40)),
        comment: 'Musterdaten der Demo',
      ),
    );
    await repos.contracts.save(
      Contract(
        type: ContractType.leasing,
        title: 'Leasing Lieferwagen',
        partner: 'Leasing Beispiel GmbH',
        startDate: DateTime(now.year - 1, 6, 1),
        endDate: DateTime(now.year + 3, 5, 31),
        rate: const Money(38000),
        rhythm: PaymentRhythm.monthly,
        vatPermille: 200,
        comment: 'Musterdaten der Demo',
      ),
    );
    // Dienstvertrag mit erfundener Person (Personendaten Beschäftigter,
    // L-23.8: nie Teil einer KI-Übertragung).
    await repos.contracts.save(
      Contract(
        type: ContractType.service,
        title: 'Dienstvertrag Teilzeitkraft Lager',
        partner: 'Lena Beispiel (erfunden)',
        startDate: DateTime(now.year, 3, 1),
        noticeValue: 4,
        noticeUnit: NoticeUnit.weeks,
        rate: const Money(98000),
        rhythm: PaymentRhythm.monthly,
        comment: '20 Wochenstunden, Musterdaten der Demo',
      ),
    );
    await repos.contracts.save(
      Contract(
        type: ContractType.insurance,
        title: 'Betriebshaftpflicht',
        partner: 'Versicherung Beispiel AG',
        startDate: DateTime(now.year - 1, 3, 1),
        noticeValue: 1,
        noticeUnit: NoticeUnit.months,
        rate: const Money(21000),
        rhythm: PaymentRhythm.quarterly,
      ),
    );
  }

  static String _amount(Money m) {
    final c = m.cents.abs();
    final euros = c ~/ 100;
    final cents = (c % 100).toString().padLeft(2, '0');
    return '${m.cents < 0 ? '-' : ''}$euros,$cents';
  }
}
