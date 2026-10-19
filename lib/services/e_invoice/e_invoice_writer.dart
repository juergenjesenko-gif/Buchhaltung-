import 'package:xml/xml.dart';

import '../../domain/company_profile.dart';
import '../../domain/customer.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../invoice_totals.dart';

/// Eingabe für eine E-Rechnung (FA-5.49): gestellte Rechnung oder
/// Stornorechnung mit den eingefrorenen Absenderangaben (GR-8) und der
/// Kundin.
class EInvoiceInput {
  const EInvoiceInput({
    required this.invoice,
    required this.seller,
    required this.buyer,
  });

  final Invoice invoice;
  final CompanyProfile seller;
  final Customer buyer;

  /// Stornorechnung (L-3.7) wird als Gutschrift-Rechnung mit Art 381
  /// (UNTDID 1001 „Credit note“) bzw. ebInterface `CreditMemo` mit
  /// **positiven** Beträgen geschrieben – das Vorzeichen steckt in der Art.
  bool get isCreditNote => invoice.isCancellation;

  /// Summen ohne Vorzeichenwechsel des Stornos.
  InvoiceTotals get totals => InvoiceTotals.compute(
    items: invoice.items,
    isSmallBusiness: invoice.isSmallBusiness,
    discountPermille: invoice.discountPermille,
    discountAmount: invoice.discountAmount,
    shipping: invoice.shipping,
    shippingVatPermille: invoice.shippingVatPermille,
  );

  /// Steuerkategorie nach UNTDID 5305: Kleinunternehmer `E` (steuerbefreit,
  /// § 19 UStG DE / § 6 Abs 1 Z 27 UStG AT, P-S86), Satz > 0 `S`, Satz 0 bei
  /// Regelbesteuerung `Z`.
  String categoryFor(int permille) {
    if (invoice.isSmallBusiness) return 'E';
    return permille > 0 ? 'S' : 'Z';
  }
}

/// Fehlende Angaben für ein gültiges Format. Leere Liste = alles da.
class EInvoiceCheck {
  const EInvoiceCheck._();

  static List<String> missing(EInvoiceFormat format, EInvoiceInput input) {
    final s = input.seller;
    final b = input.buyer;
    bool empty(String v) => v.trim().isEmpty;
    final out = <String>[
      if (empty(s.companyName)) 'Name oder Firma in den Stammdaten',
      if (empty(s.street) || empty(s.postalCode) || empty(s.city))
        'Deine Anschrift in den Stammdaten',
      if (empty(s.vatId) && empty(s.taxNumber))
        'UID bzw. USt-IdNr. oder Steuernummer in den Stammdaten',
      if (empty(b.postalCode) || empty(b.city))
        'Postleitzahl und Ort der Kundin',
    ];
    if (format == EInvoiceFormat.xrechnung) {
      out.addAll([
        if (empty(b.buyerReference)) 'Leitweg-ID der Kundin',
        if (empty(b.email)) 'E-Mail-Adresse der Kundin',
        if (empty(s.email)) 'Deine E-Mail-Adresse in den Stammdaten',
        if (empty(s.phone)) 'Deine Telefonnummer in den Stammdaten',
        if (empty(s.iban)) 'Deine IBAN in den Stammdaten',
      ]);
    }
    if (format == EInvoiceFormat.ebInterface) {
      out.addAll([
        if (empty(b.buyerReference)) 'Auftragsreferenz der Kundin',
        if (empty(b.supplierNumber)) 'Deine Lieferantennummer bei der Kundin',
        if (empty(s.iban)) 'Deine IBAN in den Stammdaten',
      ]);
    }
    return out;
  }
}

/// Schreibt E-Rechnungen (FA-5.49) als XML.
///
/// * **CII** (UN/CEFACT Cross Industry Invoice D16B, EN 16931-1, Syntax nach
///   CEN/TS 16931-3-3): ZUGFeRD 2.x/Factur-X Profil EN 16931 (in die PDF/A-3
///   eingebettet) und XRechnung 3.0 (CII-Syntax).
/// * **ebInterface 6.1** (Österreich, e-Rechnung.gv.at).
///
/// Beträge kommen aus [InvoiceTotals] – derselben Rechnung wie das PDF; die
/// Umsatzsteuer ist dort je Position gerundet (GR-5). Gelesen werden die
/// Dateien vom vorhandenen `EInvoiceParser` (Rundreise-Test).
class EInvoiceWriter {
  const EInvoiceWriter._();

  /// Spezifikationskennung ZUGFeRD/Factur-X EN 16931 (BT-24).
  static const guidelineEn16931 = 'urn:cen.eu:en16931:2017';

  /// Spezifikationskennung XRechnung 3.0 (BT-24).
  static const guidelineXRechnung =
      'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0';

  /// Geschäftsprozess (BT-23), von XRechnung verlangt.
  static const businessProcess = 'urn:fdc:peppol.eu:2017:poacc:billing:01.0';

  static const _rsm =
      'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100';
  static const _ram =
      'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100';
  static const _qdt =
      'urn:un:unece:uncefact:data:standard:QualifiedDataType:100';
  static const _udt =
      'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100';

  static const ebInterfaceNamespace = 'http://www.ebinterface.at/schema/6p1/';

  /// Name der eingebetteten Datei in der ZUGFeRD-PDF (Factur-X 1.0,
  /// ZUGFeRD 2.1 ff.).
  static const zugferdFileName = 'factur-x.xml';

  // ------------------------------------------------------------------ CII

  static String cii(EInvoiceInput input, {bool xrechnung = false}) {
    final inv = input.invoice;
    final s = input.seller;
    final b = input.buyer;
    final totals = input.totals;
    final x = XmlBuilder();
    x.processing('xml', 'version="1.0" encoding="UTF-8"');
    void el(String name, Object? text, {Map<String, String> attrs = const {}}) {
      x.element(
        name,
        nest: () {
          attrs.forEach(x.attribute);
          if (text != null) x.text(text.toString());
        },
      );
    }

    void node(String name, void Function() nest) => x.element(name, nest: nest);
    void date(String wrapper, DateTime d, {String prefix = 'udt'}) =>
        node(wrapper, () {
          el('$prefix:DateTimeString', _ymd(d), attrs: const {'format': '102'});
        });
    void tax(int permille) => node('ram:ApplicableTradeTax', () {
      el('ram:TypeCode', 'VAT');
      el('ram:CategoryCode', input.categoryFor(permille));
      el('ram:RateApplicablePercent', _percent(permille));
    });
    void allowanceCharge({
      required bool charge,
      required Money amount,
      required String reason,
      required int permille,
    }) => node('ram:SpecifiedTradeAllowanceCharge', () {
      node('ram:ChargeIndicator', () => el('udt:Indicator', '$charge'));
      el('ram:ActualAmount', _amount(amount));
      el('ram:Reason', reason);
      node('ram:CategoryTradeTax', () {
        el('ram:TypeCode', 'VAT');
        el('ram:CategoryCode', input.categoryFor(permille));
        el('ram:RateApplicablePercent', _percent(permille));
      });
    });

    final exemption = s.taxProfile.smallBusinessInvoiceNote;

    x.element(
      'rsm:CrossIndustryInvoice',
      namespaceUris: const {'rsm': _rsm, 'ram': _ram, 'qdt': _qdt, 'udt': _udt},
      nest: () {
        node('rsm:ExchangedDocumentContext', () {
          if (xrechnung) {
            node(
              'ram:BusinessProcessSpecifiedDocumentContextParameter',
              () => el('ram:ID', businessProcess),
            );
          }
          node(
            'ram:GuidelineSpecifiedDocumentContextParameter',
            () =>
                el('ram:ID', xrechnung ? guidelineXRechnung : guidelineEn16931),
          );
        });
        node('rsm:ExchangedDocument', () {
          el('ram:ID', inv.number);
          el('ram:TypeCode', input.isCreditNote ? '381' : '380');
          date('ram:IssueDateTime', inv.issueDate);
          if (input.isCreditNote && inv.cancelReason.trim().isNotEmpty) {
            node(
              'ram:IncludedNote',
              () => el('ram:Content', 'Storno: ${inv.cancelReason.trim()}'),
            );
          }
          if (inv.notes.trim().isNotEmpty) {
            node('ram:IncludedNote', () => el('ram:Content', inv.notes.trim()));
          }
          if (inv.isSmallBusiness) {
            node('ram:IncludedNote', () {
              el('ram:Content', exemption);
              el('ram:SubjectCode', 'REG');
            });
          }
        });
        node('rsm:SupplyChainTradeTransaction', () {
          var lineNo = 0;
          for (final item in inv.items) {
            lineNo++;
            final rate = inv.isSmallBusiness ? 0 : item.vatPermille;
            node('ram:IncludedSupplyChainTradeLineItem', () {
              node(
                'ram:AssociatedDocumentLineDocument',
                () => el('ram:LineID', '$lineNo'),
              );
              node(
                'ram:SpecifiedTradeProduct',
                () => el(
                  'ram:Name',
                  item.description.trim().isEmpty
                      ? 'Position $lineNo'
                      : item.description.trim(),
                ),
              );
              node('ram:SpecifiedLineTradeAgreement', () {
                node(
                  'ram:NetPriceProductTradePrice',
                  () => el('ram:ChargeAmount', _amount(item.unitPrice)),
                );
              });
              node('ram:SpecifiedLineTradeDelivery', () {
                el(
                  'ram:BilledQuantity',
                  _quantity(item.quantityMilli),
                  attrs: {'unitCode': unitCode(item.unit)},
                );
              });
              node('ram:SpecifiedLineTradeSettlement', () {
                tax(rate);
                if (item.hasDiscount) {
                  node('ram:SpecifiedTradeAllowanceCharge', () {
                    node(
                      'ram:ChargeIndicator',
                      () => el('udt:Indicator', 'false'),
                    );
                    el('ram:ActualAmount', _amount(item.discount));
                    el('ram:Reason', 'Rabatt');
                  });
                }
                node(
                  'ram:SpecifiedTradeSettlementLineMonetarySummation',
                  () => el('ram:LineTotalAmount', _amount(item.net)),
                );
              });
            });
          }

          node('ram:ApplicableHeaderTradeAgreement', () {
            if (b.buyerReference.trim().isNotEmpty) {
              el('ram:BuyerReference', b.buyerReference.trim());
            }
            node('ram:SellerTradeParty', () {
              // BR-CO-26: ohne UID die Firmenbuch-/Registernummer (BT-30)
              // bzw. die Steuernummer als Kennung (BT-29, P-S86).
              if (s.vatId.trim().isEmpty && s.registerNumber.trim().isEmpty) {
                el('ram:ID', s.taxNumber.trim());
              }
              el('ram:Name', s.companyName);
              if (s.vatId.trim().isEmpty &&
                  s.registerNumber.trim().isNotEmpty) {
                node(
                  'ram:SpecifiedLegalOrganization',
                  () => el('ram:ID', s.registerNumber.trim()),
                );
              }
              if (xrechnung ||
                  s.phone.trim().isNotEmpty ||
                  s.email.trim().isNotEmpty) {
                node('ram:DefinedTradeContact', () {
                  el(
                    'ram:PersonName',
                    s.ownerName.trim().isEmpty ? s.companyName : s.ownerName,
                  );
                  if (s.phone.trim().isNotEmpty) {
                    node(
                      'ram:TelephoneUniversalCommunication',
                      () => el('ram:CompleteNumber', s.phone.trim()),
                    );
                  }
                  if (s.email.trim().isNotEmpty) {
                    node(
                      'ram:EmailURIUniversalCommunication',
                      () => el('ram:URIID', s.email.trim()),
                    );
                  }
                });
              }
              node('ram:PostalTradeAddress', () {
                el('ram:PostcodeCode', s.postalCode);
                el('ram:LineOne', s.street);
                el('ram:CityName', s.city);
                el('ram:CountryID', s.country.code);
              });
              if (s.email.trim().isNotEmpty) {
                node(
                  'ram:URIUniversalCommunication',
                  () => el(
                    'ram:URIID',
                    s.email.trim(),
                    attrs: const {'schemeID': 'EM'},
                  ),
                );
              }
              if (s.vatId.trim().isNotEmpty) {
                node(
                  'ram:SpecifiedTaxRegistration',
                  () => el(
                    'ram:ID',
                    _compact(s.vatId),
                    attrs: const {'schemeID': 'VA'},
                  ),
                );
              }
              if (s.taxNumber.trim().isNotEmpty) {
                node(
                  'ram:SpecifiedTaxRegistration',
                  () => el(
                    'ram:ID',
                    s.taxNumber.trim(),
                    attrs: const {'schemeID': 'FC'},
                  ),
                );
              }
            });
            node('ram:BuyerTradeParty', () {
              el('ram:Name', b.name);
              node('ram:PostalTradeAddress', () {
                el('ram:PostcodeCode', b.postalCode);
                if (b.street.trim().isNotEmpty) el('ram:LineOne', b.street);
                el('ram:CityName', b.city);
                el('ram:CountryID', b.country.code);
              });
              if (b.email.trim().isNotEmpty) {
                node(
                  'ram:URIUniversalCommunication',
                  () => el(
                    'ram:URIID',
                    b.email.trim(),
                    attrs: const {'schemeID': 'EM'},
                  ),
                );
              }
              if (b.vatId.trim().isNotEmpty) {
                node(
                  'ram:SpecifiedTaxRegistration',
                  () => el(
                    'ram:ID',
                    _compact(b.vatId),
                    attrs: const {'schemeID': 'VA'},
                  ),
                );
              }
            });
          });

          node('ram:ApplicableHeaderTradeDelivery', () {
            node(
              'ram:ActualDeliverySupplyChainEvent',
              () => date(
                'ram:OccurrenceDateTime',
                inv.deliveryDate ?? inv.issueDate,
              ),
            );
          });

          node('ram:ApplicableHeaderTradeSettlement', () {
            if (!input.isCreditNote) el('ram:PaymentReference', inv.number);
            el('ram:InvoiceCurrencyCode', 'EUR');
            if (s.iban.trim().isNotEmpty) {
              node('ram:SpecifiedTradeSettlementPaymentMeans', () {
                el('ram:TypeCode', '58');
                node(
                  'ram:PayeePartyCreditorFinancialAccount',
                  () => el('ram:IBANID', _compact(s.iban)),
                );
                if (s.bic.trim().isNotEmpty) {
                  node(
                    'ram:PayeeSpecifiedCreditorFinancialInstitution',
                    () => el('ram:BICID', _compact(s.bic)),
                  );
                }
              });
            }
            for (final entry in totals.breakdown.entries) {
              final category = input.categoryFor(entry.key);
              node('ram:ApplicableTradeTax', () {
                el('ram:CalculatedAmount', _amount(entry.value.vat));
                el('ram:TypeCode', 'VAT');
                if (category == 'E') el('ram:ExemptionReason', exemption);
                el('ram:BasisAmount', _amount(entry.value.net));
                el('ram:CategoryCode', category);
                el('ram:RateApplicablePercent', _percent(entry.key));
              });
            }
            for (final line in totals.discountLines) {
              allowanceCharge(
                charge: false,
                amount: line.net.abs,
                reason: 'Rabatt',
                permille: line.vatPermille,
              );
            }
            for (final line in totals.shippingLines) {
              allowanceCharge(
                charge: true,
                amount: line.net,
                reason: 'Versandkosten',
                permille: line.vatPermille,
              );
            }
            node('ram:SpecifiedTradePaymentTerms', () {
              el('ram:Description', paymentTermsText(input));
              if (!input.isCreditNote && inv.dueDate != null) {
                date('ram:DueDateDateTime', inv.dueDate!);
              }
            });
            node('ram:SpecifiedTradeSettlementHeaderMonetarySummation', () {
              el(
                'ram:LineTotalAmount',
                _amount(inv.items.map((i) => i.net).sum),
              );
              el('ram:ChargeTotalAmount', _amount(totals.shipping));
              el('ram:AllowanceTotalAmount', _amount(totals.discount));
              el('ram:TaxBasisTotalAmount', _amount(totals.net));
              el(
                'ram:TaxTotalAmount',
                _amount(totals.vat),
                attrs: const {'currencyID': 'EUR'},
              );
              el('ram:GrandTotalAmount', _amount(totals.gross));
              el('ram:TotalPrepaidAmount', _amount(const Money.zero()));
              el('ram:DuePayableAmount', _amount(totals.gross));
            });
            if (input.isCreditNote && inv.cancelsNumber.isNotEmpty) {
              node('ram:InvoiceReferencedDocument', () {
                el('ram:IssuerAssignedID', inv.cancelsNumber);
                if (inv.cancelsIssueDate != null) {
                  date(
                    'ram:FormattedIssueDateTime',
                    inv.cancelsIssueDate!,
                    prefix: 'qdt',
                  );
                }
              });
            }
          });
        });
      },
    );
    return x.buildDocument().toXmlString(pretty: true);
  }

  /// Zahlungsbedingungen (BT-20). Skonto zusätzlich in der maschinenlesbaren
  /// XRechnung-Schreibweise `#SKONTO#TAGE=7#PROZENT=2.00#` in eigener Zeile
  /// (XRechnung 3.0, Kapitel „Skonto“; von ZUGFeRD-Empfängern als Text
  /// gelesen).
  static String paymentTermsText(EInvoiceInput input) {
    final inv = input.invoice;
    if (input.isCreditNote) {
      return 'Gutschrift zur Rechnung ${inv.cancelsNumber}.';
    }
    final due = inv.dueDate;
    final text = due == null
        ? 'Zahlbar ohne Abzug.'
        : 'Zahlbar bis ${_dmy(due)} ohne Abzug.';
    if (!inv.hasSkonto) return text;
    final p = inv.skontoPermille;
    final percent = '${p ~/ 10}.${(p % 10)}0';
    return '$text\n#SKONTO#TAGE=${inv.skontoDays}#PROZENT=$percent#\n';
  }

  // ---------------------------------------------------------- ebInterface

  static String ebInterface(EInvoiceInput input) {
    final inv = input.invoice;
    final s = input.seller;
    final b = input.buyer;
    final totals = input.totals;
    final x = XmlBuilder();
    x.processing('xml', 'version="1.0" encoding="UTF-8"');
    void el(String name, Object? text, {Map<String, String> attrs = const {}}) {
      x.element(
        name,
        nest: () {
          attrs.forEach(x.attribute);
          if (text != null) x.text(text.toString());
        },
      );
    }

    void node(String name, void Function() nest) => x.element(name, nest: nest);
    void taxItem(Money taxable, int permille, Money vat) => node('TaxItem', () {
      el('TaxableAmount', _amount(taxable));
      el(
        'TaxPercent',
        _amount(Money(permille * 10)),
        attrs: {'TaxCategoryCode': input.categoryFor(permille)},
      );
      el('TaxAmount', _amount(vat));
      if (input.categoryFor(permille) == 'E') {
        el('Comment', s.taxProfile.smallBusinessInvoiceNote);
      }
    });
    void address(
      String name,
      String street,
      String town,
      String zip,
      String countryCode,
      String countryLabel,
      String email,
    ) => node('Address', () {
      el('Name', name);
      if (street.trim().isNotEmpty) el('Street', street);
      el('Town', town);
      el('ZIP', zip);
      el('Country', countryLabel, attrs: {'CountryCode': countryCode});
      if (email.trim().isNotEmpty) el('Email', email.trim());
    });

    x.element(
      'Invoice',
      namespaceUris: const {null: ebInterfaceNamespace},
      nest: () {
        x.attribute('GeneratingSystem', 'JeNi bucht');
        x.attribute(
          'DocumentType',
          input.isCreditNote ? 'CreditMemo' : 'Invoice',
        );
        x.attribute('InvoiceCurrency', 'EUR');
        x.attribute('Language', 'de');
        el('InvoiceNumber', inv.number);
        el('InvoiceDate', _isoDate(inv.issueDate));
        if (input.isCreditNote && inv.cancelsNumber.isNotEmpty) {
          node('CancelledOriginalDocument', () {
            el('InvoiceNumber', inv.cancelsNumber);
            el('InvoiceDate', _isoDate(inv.cancelsIssueDate ?? inv.issueDate));
            if (inv.cancelReason.trim().isNotEmpty) {
              el('Comment', inv.cancelReason.trim());
            }
          });
        }
        node(
          'Delivery',
          () => el('Date', _isoDate(inv.deliveryDate ?? inv.issueDate)),
        );
        node('Biller', () {
          // Ohne UID verlangt ebInterface „00000000“ (Kleinunternehmer).
          el(
            'VATIdentificationNumber',
            s.vatId.trim().isEmpty ? '00000000' : _compact(s.vatId),
          );
          address(
            s.companyName,
            s.street,
            s.city,
            s.postalCode,
            s.country.code,
            s.country.label,
            s.email,
          );
          if (b.supplierNumber.trim().isNotEmpty) {
            el('InvoiceRecipientsBillerID', b.supplierNumber.trim());
          }
        });
        node('InvoiceRecipient', () {
          el(
            'VATIdentificationNumber',
            b.vatId.trim().isEmpty ? '00000000' : _compact(b.vatId),
          );
          if (b.buyerReference.trim().isNotEmpty) {
            node(
              'OrderReference',
              () => el('OrderID', b.buyerReference.trim()),
            );
          }
          address(
            b.name,
            b.street,
            b.city,
            b.postalCode,
            b.country.code,
            b.country.label,
            b.email,
          );
        });
        node('Details', () {
          node('ItemList', () {
            var no = 0;
            for (final item in inv.items) {
              no++;
              final rate = inv.isSmallBusiness ? 0 : item.vatPermille;
              node('ListLineItem', () {
                el('PositionNumber', '$no');
                el(
                  'Description',
                  item.description.trim().isEmpty
                      ? 'Position $no'
                      : item.description.trim(),
                );
                el(
                  'Quantity',
                  _quantity(item.quantityMilli),
                  attrs: {'Unit': unitCode(item.unit)},
                );
                el('UnitPrice', _amount(item.unitPrice));
                if (item.hasDiscount) {
                  node('ReductionAndSurchargeListLineItemDetails', () {
                    node('ReductionListLineItem', () {
                      el('BaseAmount', _amount(item.lineAmount));
                      el('Amount', _amount(item.discount));
                      el('Comment', 'Rabatt');
                    });
                  });
                }
                taxItem(
                  item.net,
                  rate,
                  inv.isSmallBusiness ? const Money.zero() : item.vat,
                );
                el('LineItemAmount', _amount(item.net));
              });
            }
          });
        });
        if (totals.discountLines.isNotEmpty ||
            totals.shippingLines.isNotEmpty) {
          node('ReductionAndSurchargeDetails', () {
            for (final line in totals.discountLines) {
              node('Reduction', () {
                el(
                  'BaseAmount',
                  _amount(
                    totals.itemNetByRate[line.vatPermille] ??
                        const Money.zero(),
                  ),
                );
                el('Amount', _amount(line.net.abs));
                el('Comment', 'Rabatt');
                taxItem(
                  line.net.abs,
                  line.vatPermille,
                  line.vatFor(isSmallBusiness: inv.isSmallBusiness).abs,
                );
              });
            }
            for (final line in totals.shippingLines) {
              node('Surcharge', () {
                el('BaseAmount', _amount(line.net));
                el('Amount', _amount(line.net));
                el('Comment', 'Versandkosten');
                taxItem(
                  line.net,
                  line.vatPermille,
                  line.vatFor(isSmallBusiness: inv.isSmallBusiness),
                );
              });
            }
          });
        }
        node('Tax', () {
          for (final e in totals.breakdown.entries) {
            taxItem(e.value.net, e.key, e.value.vat);
          }
        });
        el('TotalGrossAmount', _amount(totals.gross));
        el('PayableAmount', _amount(totals.gross));
        if (s.iban.trim().isNotEmpty) {
          node('PaymentMethod', () {
            node('UniversalBankTransaction', () {
              node('BeneficiaryAccount', () {
                if (s.bic.trim().isNotEmpty) el('BIC', _compact(s.bic));
                el('IBAN', _compact(s.iban));
                el('BankAccountOwner', s.companyName);
              });
              if (!input.isCreditNote) el('PaymentReference', inv.number);
            });
          });
        }
        if (!input.isCreditNote && (inv.dueDate != null || inv.hasSkonto)) {
          node('PaymentConditions', () {
            if (inv.dueDate != null) el('DueDate', _isoDate(inv.dueDate!));
            if (inv.hasSkonto) {
              node('Discount', () {
                el('PaymentDate', _isoDate(inv.skontoDate!));
                el('BaseAmount', _amount(totals.gross));
                el('Percentage', _amount(Money(inv.skontoPermille * 10)));
              });
            }
          });
        }
      },
    );
    return x.buildDocument().toXmlString(pretty: true);
  }

  // ------------------------------------------------------------- Formate

  /// Mengeneinheit nach UN/ECE Rec. 20 (BT-130). Unbekanntes → `C62`
  /// („Stück/Einheit“).
  static String unitCode(String unit) {
    final u = unit.trim().toLowerCase().replaceAll('.', '');
    return switch (u) {
      'std' || 'h' || 'stunde' || 'stunden' => 'HUR',
      'min' || 'minute' || 'minuten' => 'MIN',
      'tag' || 'tage' || 'd' => 'DAY',
      'woche' || 'wochen' => 'WEE',
      'monat' || 'monate' => 'MON',
      'jahr' || 'jahre' => 'ANN',
      'kg' => 'KGM',
      'g' => 'GRM',
      't' => 'TNE',
      'm' => 'MTR',
      'km' => 'KMT',
      'm2' || 'm²' || 'qm' => 'MTK',
      'm3' || 'm³' => 'MTQ',
      'l' || 'liter' => 'LTR',
      'pausch' || 'pauschal' || 'psch' || 'pauschale' => 'LS',
      _ => 'C62',
    };
  }

  static String _amount(Money m) {
    final c = m.cents;
    final a = c.abs();
    return '${c < 0 ? '-' : ''}${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
  }

  static String _percent(int permille) => permille % 10 == 0
      ? '${permille ~/ 10}'
      : '${permille ~/ 10}.${permille % 10}';

  static String _quantity(int milli) {
    final a = milli.abs();
    return '${milli < 0 ? '-' : ''}${a ~/ 1000}.${(a % 1000).toString().padLeft(3, '0')}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _ymd(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';
  static String _isoDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _dmy(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
  static String _compact(String v) => v.replaceAll(RegExp(r'\s'), '');
}
