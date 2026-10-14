import 'package:xml/xml.dart';

import '../../domain/money.dart';
import 'receipt_codes.dart' show isValidIban;

/// Steuersatzzeile einer E-Rechnung: Bemessung und Steuer je Satz.
typedef EInvoiceVat = ({int permille, Money net, Money vat});

/// Strukturierte Rechnung aus XML (L-27.6). Beträge in Cent (GR-1), Sätze in
/// Promille (GR-3).
class EInvoice {
  const EInvoice({
    required this.format,
    this.number,
    this.date,
    this.seller,
    this.sellerVatId,
    this.currency = 'EUR',
    this.gross,
    this.vatLines = const [],
    this.iban,
    this.isCreditNote = false,
  });

  /// „ZUGFeRD/Factur-X/XRechnung (CII)“, „XRechnung (UBL)“, „ebInterface“.
  final String format;
  final String? number;
  final DateTime? date;
  final String? seller;
  final String? sellerVatId;
  final String currency;

  /// Rechnungsbetrag brutto (CII GrandTotalAmount, UBL TaxInclusiveAmount,
  /// ebInterface TotalGrossAmount).
  final Money? gross;
  final List<EInvoiceVat> vatLines;
  final String? iban;
  final bool isCreditNote;
}

/// Liest die drei im DACH-Raum üblichen XML-Rechnungsformate, unabhängig vom
/// Namensraum-Präfix:
///
/// * **UN/CEFACT CII** (`CrossIndustryInvoice`): ZUGFeRD 2.x, Factur-X,
///   XRechnung-CII – EN 16931-1, Syntax-Bindung CEN/TS 16931-3-3.
/// * **OASIS UBL 2.1** (`Invoice`, `CreditNote`): XRechnung-UBL, Peppol –
///   CEN/TS 16931-3-2.
/// * **ebInterface** (AT, `http://www.ebinterface.at/schema/…`), Versionen
///   4.x bis 6.x: `Tax/VAT/VATItem` bzw. ab 6.0 `Tax/TaxItem`.
///
/// Gibt `null` zurück, wenn das XML keinem dieser Formate entspricht oder
/// nicht wohlgeformt ist. DOCTYPE wird abgelehnt (kein XXE).
class EInvoiceParser {
  const EInvoiceParser._();

  static EInvoice? parse(String source) {
    if (source.contains('<!DOCTYPE') || source.contains('<!ENTITY')) {
      return null;
    }
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(source);
    } on XmlException {
      return null;
    }
    final root = doc.rootElement;
    final ns = root.namespaceUri ?? '';
    if (root.localName == 'CrossIndustryInvoice') return _cii(root);
    if (ns.contains('ebinterface')) return _ebInterface(root);
    if (root.localName == 'Invoice' || root.localName == 'CreditNote') {
      if (ns.contains('oasis') || ns.contains('ubl')) return _ubl(root);
    }
    return null;
  }

  // ---------------------------------------------------------------- CII

  static EInvoice _cii(XmlElement root) {
    final doc = _first(root, ['ExchangedDocument']);
    final settlement = _first(root, [
      'SupplyChainTradeTransaction',
      'ApplicableHeaderTradeSettlement',
    ]);
    final seller = _first(root, [
      'SupplyChainTradeTransaction',
      'ApplicableHeaderTradeAgreement',
      'SellerTradeParty',
    ]);
    String? vatId;
    for (final reg in _children(seller, 'SpecifiedTaxRegistration')) {
      final id = _child(reg, 'ID');
      if (id?.getAttribute('schemeID') == 'VA') vatId = _text(id);
    }
    final lines = <EInvoiceVat>[];
    for (final tax in _children(settlement, 'ApplicableTradeTax')) {
      final permille = _permille(_text(_child(tax, 'RateApplicablePercent')));
      final net = _cents(_text(_child(tax, 'BasisAmount')));
      final vat = _cents(_text(_child(tax, 'CalculatedAmount')));
      if (permille != null && net != null && vat != null) {
        lines.add((permille: permille, net: Money(net), vat: Money(vat)));
      }
    }
    final sum = _first(settlement, [
      'SpecifiedTradeSettlementHeaderMonetarySummation',
    ]);
    final iban = _text(
      _first(settlement, [
        'SpecifiedTradeSettlementPaymentMeans',
        'PayeePartyCreditorFinancialAccount',
        'IBANID',
      ]),
    );
    final typeCode = _text(_child(doc, 'TypeCode'));
    return EInvoice(
      format: 'ZUGFeRD/Factur-X/XRechnung (CII)',
      number: _text(_child(doc, 'ID')),
      date: _date(_text(_first(doc, ['IssueDateTime', 'DateTimeString']))),
      seller: _text(_child(seller, 'Name')),
      sellerVatId: _vatId(vatId),
      currency: _text(_child(settlement, 'InvoiceCurrencyCode')) ?? 'EUR',
      gross: _money(_text(_child(sum, 'GrandTotalAmount'))),
      vatLines: lines,
      iban: _iban(iban),
      isCreditNote: typeCode == '381',
    );
  }

  // ---------------------------------------------------------------- UBL

  static EInvoice _ubl(XmlElement root) {
    final party = _first(root, ['AccountingSupplierParty', 'Party']);
    final name =
        _text(_first(party, ['PartyLegalEntity', 'RegistrationName'])) ??
        _text(_first(party, ['PartyName', 'Name']));
    String? vatId;
    for (final scheme in _children(party, 'PartyTaxScheme')) {
      final id = _text(_child(scheme, 'CompanyID'));
      final kind = _text(_first(scheme, ['TaxScheme', 'ID']));
      if (kind == null || kind == 'VAT') vatId ??= id;
    }
    final lines = <EInvoiceVat>[];
    for (final total in _children(root, 'TaxTotal')) {
      for (final sub in _children(total, 'TaxSubtotal')) {
        final permille = _permille(
          _text(_first(sub, ['TaxCategory', 'Percent'])),
        );
        final net = _cents(_text(_child(sub, 'TaxableAmount')));
        final vat = _cents(_text(_child(sub, 'TaxAmount')));
        if (permille != null && net != null && vat != null) {
          lines.add((permille: permille, net: Money(net), vat: Money(vat)));
        }
      }
    }
    final monetary = _child(root, 'LegalMonetaryTotal');
    String? iban;
    for (final means in _children(root, 'PaymentMeans')) {
      iban ??= _text(_first(means, ['PayeeFinancialAccount', 'ID']));
    }
    return EInvoice(
      format: 'XRechnung/UBL',
      number: _text(_child(root, 'ID')),
      date: _date(_text(_child(root, 'IssueDate'))),
      seller: name,
      sellerVatId: _vatId(vatId),
      currency: _text(_child(root, 'DocumentCurrencyCode')) ?? 'EUR',
      gross:
          _money(_text(_child(monetary, 'TaxInclusiveAmount'))) ??
          _money(_text(_child(monetary, 'PayableAmount'))),
      vatLines: lines,
      iban: _iban(iban),
      isCreditNote: root.localName == 'CreditNote',
    );
  }

  // --------------------------------------------------------- ebInterface

  static EInvoice _ebInterface(XmlElement root) {
    final biller = _child(root, 'Biller');
    final lines = <EInvoiceVat>[];
    final tax = _child(root, 'Tax');
    // ab 6.0: Tax/TaxItem(TaxableAmount, TaxPercent, TaxAmount)
    for (final item in _children(tax, 'TaxItem')) {
      final permille = _permille(_text(_child(item, 'TaxPercent')));
      final net = _cents(_text(_child(item, 'TaxableAmount')));
      final vat = _cents(_text(_child(item, 'TaxAmount')));
      if (permille != null && net != null && vat != null) {
        lines.add((permille: permille, net: Money(net), vat: Money(vat)));
      }
    }
    // 4.x/5.x: Tax/VAT/VATItem(TaxedAmount, VATRate, Amount)
    for (final item in _children(_child(tax, 'VAT'), 'VATItem')) {
      final permille = _permille(_text(_child(item, 'VATRate')));
      final net = _cents(_text(_child(item, 'TaxedAmount')));
      final vat = _cents(_text(_child(item, 'Amount')));
      if (permille != null && net != null && vat != null) {
        lines.add((permille: permille, net: Money(net), vat: Money(vat)));
      }
    }
    final iban = _text(
      _first(root, [
        'PaymentMethod',
        'UniversalBankTransaction',
        'BeneficiaryAccount',
        'IBAN',
      ]),
    );
    return EInvoice(
      format: 'ebInterface',
      number: _text(_child(root, 'InvoiceNumber')),
      date: _date(_text(_child(root, 'InvoiceDate'))),
      seller: _text(_first(biller, ['Address', 'Name'])),
      sellerVatId: _vatId(_text(_child(biller, 'VATIdentificationNumber'))),
      currency: root.getAttribute('InvoiceCurrency') ?? 'EUR',
      gross: _money(_text(_child(root, 'TotalGrossAmount'))),
      vatLines: lines,
      iban: _iban(iban),
      isCreditNote: root.getAttribute('DocumentType') == 'CreditMemo',
    );
  }

  // ------------------------------------------------------------ Hilfen

  static XmlElement? _child(XmlElement? e, String local) {
    if (e == null) return null;
    for (final c in e.childElements) {
      if (c.localName == local) return c;
    }
    return null;
  }

  static Iterable<XmlElement> _children(XmlElement? e, String local) =>
      e == null ? const [] : e.childElements.where((c) => c.localName == local);

  static XmlElement? _first(XmlElement? e, List<String> path) {
    var current = e;
    for (final step in path) {
      current = _child(current, step);
      if (current == null) return null;
    }
    return current;
  }

  static String? _text(XmlElement? e) {
    final t = e?.innerText.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Dezimalzahl mit Punkt, beliebig viele Nachkommastellen, kaufmännisch
  /// auf Cent gerundet – ohne Gleitkomma (GR-1).
  static int? _cents(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(s);
    if (m == null) return null;
    final fraction = (m.group(3) ?? '').padRight(3, '0');
    var cents =
        int.parse(m.group(2)!) * 100 + int.parse(fraction.substring(0, 2));
    if (int.parse(fraction[2]) >= 5) cents += 1;
    return m.group(1) == '-' ? -cents : cents;
  }

  static Money? _money(String? s) {
    final c = _cents(s);
    return c == null ? null : Money(c);
  }

  /// „19“, „19.00“, „4.9“ → Promille; mehr als eine Promillestelle → null.
  static int? _permille(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{1,2})(?:\.(\d+))?$').firstMatch(s);
    if (m == null) return null;
    final fraction = (m.group(2) ?? '0').replaceFirst(RegExp(r'0+$'), '');
    if (fraction.length > 1) return null;
    return int.parse(m.group(1)!) * 10 +
        (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  /// `20261014` (CII Format 102) oder `2026-10-14`.
  static DateTime? _date(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d{4})-?(\d{2})-?(\d{2})').firstMatch(s.trim());
    if (m == null) return null;
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(int.parse(m.group(1)!), month, day);
  }

  static String? _vatId(String? s) => s?.replaceAll(' ', '').toUpperCase();

  static String? _iban(String? s) {
    final v = s?.replaceAll(' ', '').toUpperCase();
    return v != null && isValidIban(v) ? v : null;
  }
}
