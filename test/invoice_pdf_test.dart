import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/invoice_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Diese Tests prüfen nicht das Aussehen, sondern dass das PDF überhaupt
/// erzeugbar ist. Ein Layoutfehler im pdf-Paket wirft zur Laufzeit – und zwar
/// genau dann, wenn der Nutzer seine erste Rechnung verschicken will.
void main() {
  setUpAll(() => initializeDateFormatting('de'));

  const customer = Customer(
    id: 1,
    name: 'Beispiel GmbH',
    street: 'Ringstraße 42',
    postalCode: '1010',
    city: 'Wien',
    country: Country.at,
    vatId: 'ATU87654321',
  );

  const profile = CompanyProfile(
    companyName: 'Muster e.U.',
    ownerName: 'Maria Muster',
    country: Country.at,
    street: 'Hauptstraße 1',
    postalCode: '9020',
    city: 'Klagenfurt',
    email: 'office@muster.at',
    taxNumber: '12-345/6789',
    vatId: 'ATU12345678',
    iban: 'AT61 1904 3002 3457 3201',
    bic: 'BKAUATWW',
    bankName: 'Musterbank',
    isSmallBusiness: false,
  );

  Invoice buildInvoice({
    bool smallBusiness = false,
    int itemCount = 2,
    String notes = '',
  }) => Invoice(
    id: 1,
    number: 'RE-2026-0001',
    issueDate: DateTime(2026, 3, 1),
    deliveryDate: DateTime(2026, 2, 28),
    dueDate: DateTime(2026, 3, 15),
    customerId: 1,
    isSmallBusiness: smallBusiness,
    notes: notes,
    status: InvoiceStatus.issued,
    items: [
      for (var i = 1; i <= itemCount; i++)
        InvoiceItem(
          position: i,
          description:
              'Leistung Nummer $i mit einer etwas längeren '
              'Beschreibung, damit der Umbruch geprüft wird',
          quantityMilli: 1500,
          unit: 'Std',
          unitPrice: Money(8000 + i * 100),
          vatPermille: i.isEven ? 100 : 200,
        ),
    ],
  );

  test('erzeugt ein PDF mit Inhalt', () async {
    final bytes = await InvoicePdf(
      invoice: buildInvoice(),
      customer: customer,
      profile: profile,
    ).build();

    expect(bytes.length, greaterThan(1000));
    // Jede PDF-Datei beginnt mit "%PDF".
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('erzeugt ein PDF für Kleinunternehmer ohne Steuerspalte', () async {
    final bytes = await InvoicePdf(
      invoice: buildInvoice(smallBusiness: true),
      customer: customer,
      profile: profile.copyWith(isSmallBusiness: true),
    ).build();

    expect(bytes.length, greaterThan(1000));
  });

  test('bewältigt Umlaute, Eurozeichen und Anmerkungen', () async {
    final bytes = await InvoicePdf(
      invoice: buildInvoice(
        notes:
            'Vielen Dank für den Auftrag – Grüße aus Kärnten! '
            'Betrag in €, zahlbar netto.',
      ),
      customer: customer,
      profile: profile,
    ).build();

    expect(bytes.length, greaterThan(1000));
  });

  test('bewältigt eine Rechnung über mehrere Seiten', () async {
    final bytes = await InvoicePdf(
      invoice: buildInvoice(itemCount: 40),
      customer: customer,
      profile: profile,
    ).build();

    expect(bytes.length, greaterThan(1000));
  });

  test('funktioniert auch mit deutschem Profil', () async {
    final bytes = await InvoicePdf(
      invoice: buildInvoice(),
      customer: customer.copyWith(
        country: Country.de,
        postalCode: '10115',
        city: 'Berlin',
      ),
      profile: profile.copyWith(country: Country.de, vatId: 'DE123456789'),
    ).build();

    expect(bytes.length, greaterThan(1000));
  });

  test('funktioniert mit minimalen Stammdaten', () async {
    final bytes = await InvoicePdf(
      invoice: buildInvoice(itemCount: 1),
      customer: const Customer(id: 1, name: 'Nur ein Name'),
      profile: const CompanyProfile(
        companyName: 'Minimal',
        country: Country.at,
      ),
    ).build();

    expect(bytes.length, greaterThan(500));
  });
}
