import '../../domain/money.dart';
import '../../domain/platform_import.dart';
import 'platform_csv.dart';

/// Erkennt das Format eines Plattformexports und liest die Zeilen (L-28.1,
/// L-28.2). Gelesen werden **nur** die unten benannten Spalten; Käuferdaten
/// (Name, Adresse, E-Mail, Telefon, Ort, PLZ) werden nie angesprochen und
/// gelangen damit weder in den Speicher der App noch in die Datenbank
/// (L-28.6, Datensparsamkeit Art 5 Abs 1 lit c DSGVO).
///
/// Spaltennamen je Sprache (DE/EN/FR/IT/ES) nach Seller-Central-Hilfe und
/// Musterdateien; Abgleich mit echten Exporten: Spezifikation 14, P-S55.
class PlatformImportParser {
  const PlatformImportParser._();

  /// `null`, wenn kein bekanntes Format erkannt wurde.
  static PlatformImportFile? parse(List<int> bytes) =>
      parseText(CsvTable.decode(bytes));

  static PlatformImportFile? parseText(String text) {
    final table = CsvTable.parse(text);
    // Amazon stellt dem Transaktionsbericht einige Erklärzeilen voran; die
    // Kopfzeile wird in den ersten 20 Zeilen gesucht.
    for (var i = 0; i < table.rows.length && i < 20; i++) {
      final cols = _Columns(table.rows[i]);
      final data = table.rows.sublist(i + 1);
      final format = _detect(cols);
      if (format == null) continue;
      return switch (format) {
        PlatformFormat.amazonDateRange => _amazonDateRange(cols, data),
        PlatformFormat.amazonSettlementV2 => _amazonSettlement(cols, data),
        PlatformFormat.paypalActivity => _paypal(cols, data),
        PlatformFormat.shopifyPayouts => _shopifyPayouts(cols, data),
        PlatformFormat.shopifyOrders => _shopifyOrders(cols, data),
        PlatformFormat.stripeBalance => _stripe(cols, data),
      };
    }
    return null;
  }

  static PlatformFormat? _detect(_Columns c) {
    if (c.has(_Amz.amountType) &&
        c.has(_Amz.amountDescription) &&
        c.has(_Amz.settlementId)) {
      return PlatformFormat.amazonSettlementV2;
    }
    if (c.has(_Amz.settlementId) &&
        c.has(_Amz.type) &&
        c.has(_Amz.total) &&
        c.has(_Amz.productSales)) {
      return PlatformFormat.amazonDateRange;
    }
    if (c.has(_Shop.payoutId) && c.has(_Shop.fee) && c.has(_Shop.type)) {
      return PlatformFormat.shopifyPayouts;
    }
    if (c.has(_Shop.financialStatus) && c.has(_Shop.total)) {
      return PlatformFormat.shopifyOrders;
    }
    if (c.has(_Stripe.id) &&
        c.has(_Stripe.category) &&
        c.has(_Stripe.fee) &&
        c.has(_Stripe.created)) {
      return PlatformFormat.stripeBalance;
    }
    if (c.has(_PayPal.transactionId) &&
        c.has(_PayPal.gross) &&
        c.has(_PayPal.fee) &&
        c.has(_PayPal.net)) {
      return PlatformFormat.paypalActivity;
    }
    return null;
  }

  // ---------------------------------------------------------------- Amazon

  static PlatformImportFile _amazonDateRange(
    _Columns c,
    List<List<String>> rows,
  ) {
    final out = _Collector(PlatformFormat.amazonDateRange);
    final monthFirst = _monthFirst(rows, c.index(_Amz.date));
    for (final r in rows) {
      final date = parsePlatformDate(
        c.get(r, _Amz.date),
        monthFirst: monthFirst,
      );
      final total = parseCents(c.get(r, _Amz.total));
      if (date == null || total == null) {
        out.unreadable++;
        continue;
      }
      final type = normalizeHeader(c.get(r, _Amz.type));
      final description = normalizeHeader(c.get(r, _Amz.description));
      final order = c.get(r, _Amz.orderId).trim();
      final country = _marketplaceCountry(c.get(r, _Amz.marketplace));
      // Der Bericht hat keine Währungsspalte; Marktplätze außerhalb des
      // Euroraums rechnen in Landeswährung ab und werden nicht übernommen.
      if (_nonEuroMarketplaces.contains(country)) {
        out.foreign++;
        continue;
      }
      final fba = normalizeHeader(
        c.get(r, _Amz.fulfillment),
      ).contains('amazon');
      // Kennung aus Abrechnungsnummer und buchungsrelevantem Zeileninhalt –
      // ohne Käuferspalten, damit sich die ID nicht an Personendaten bindet.
      final key = out.uniqueKey('dr', [
        c.get(r, _Amz.settlementId),
        c.get(r, _Amz.date),
        type,
        order,
        c.get(r, _Amz.sku),
        description,
        c.get(r, _Amz.total),
      ]);
      int sum(List<List<String>> aliases) =>
          aliases.fold(0, (s, a) => s + (parseCents(c.get(r, a)) ?? 0));

      if (_isAny(type, _Amz.transferTypes)) {
        out.add(key, date, PlatformEntryKind.payout, total);
        continue;
      }
      final isOrder = _isAny(type, _Amz.orderTypes);
      final isRefund = _isAny(type, _Amz.refundTypes);
      if (isOrder || isRefund) {
        final tax = sum(_Amz.taxColumns);
        final withheld = parseCents(c.get(r, _Amz.withheldTax)) ?? 0;
        final sales = sum(_Amz.salesColumns) + tax + withheld;
        final fees = sum(_Amz.feeColumns);
        final other = parseCents(c.get(r, _Amz.other)) ?? 0;
        out.add(
          key,
          date,
          isOrder ? PlatformEntryKind.sale : PlatformEntryKind.refund,
          sales,
          tax: withheld != 0 ? 0 : tax,
          orderRef: order,
          country: country,
          fba: fba,
          marketplaceTax: withheld != 0,
        );
        if (fees != 0) {
          out.add('$key:fee', date, PlatformEntryKind.fee, fees);
        }
        if (other != 0) {
          out.add('$key:other', date, PlatformEntryKind.other, other);
        }
        continue;
      }
      if (_isAdvertising(type) || _isAdvertising(description)) {
        out.add(key, date, PlatformEntryKind.advertising, total);
      } else if (_isFee(type)) {
        out.add(key, date, PlatformEntryKind.fee, total);
      } else {
        out.add(key, date, PlatformEntryKind.other, total);
      }
    }
    return out.build();
  }

  static PlatformImportFile _amazonSettlement(
    _Columns c,
    List<List<String>> rows,
  ) {
    final out = _Collector(PlatformFormat.amazonSettlementV2);
    for (final r in rows) {
      final settlement = c.get(r, _Amz.settlementId).trim();
      final currency = c.get(r, _Amz.currency).trim().toUpperCase();
      if (currency.isNotEmpty && currency != 'EUR') {
        out.foreign++;
        continue;
      }
      final txType = normalizeHeader(c.get(r, _Amz.transactionType));
      final amountType = normalizeHeader(c.get(r, _Amz.amountType));
      // Kopfzeile der Abrechnung: Auszahlungsbetrag und -datum.
      if (txType.isEmpty && amountType.isEmpty) {
        final total = parseCents(c.get(r, _Amz.totalAmount));
        final date = parsePlatformDate(c.get(r, _Amz.depositDate));
        if (total != null && date != null && total != 0) {
          out.add(
            'settlement:$settlement:payout',
            date,
            PlatformEntryKind.payout,
            -total,
          );
        }
        continue;
      }
      final amount = parseCents(c.get(r, _Amz.amount));
      final date = parsePlatformDate(c.get(r, _Amz.postedDate));
      if (amount == null || date == null) {
        out.unreadable++;
        continue;
      }
      final desc = normalizeHeader(c.get(r, _Amz.amountDescription));
      final order = c.get(r, _Amz.orderId).trim();
      final key = out.uniqueKey('settlement:$settlement', [
        txType,
        order,
        amountType,
        desc,
        c.get(r, _Amz.postedDate),
        c.get(r, _Amz.sku),
        c.get(r, _Amz.amount),
      ]);
      final country = _marketplaceCountry(c.get(r, _Amz.marketplaceName));
      final fba = normalizeHeader(c.get(r, _Amz.fulfillmentId)) == 'afn';
      final isRefund = _isAny(txType, _Amz.refundTypes);
      if (_isAdvertising(amountType) || _isAdvertising(desc)) {
        out.add(key, date, PlatformEntryKind.advertising, amount);
      } else if (amountType == 'itemprice' ||
          amountType == 'promotion' ||
          amountType == 'itemwithheldtax') {
        final isTax = desc.contains('tax');
        out.add(
          key,
          date,
          isRefund ? PlatformEntryKind.refund : PlatformEntryKind.sale,
          amount,
          tax: isTax && amountType != 'itemwithheldtax' ? amount : 0,
          orderRef: order,
          country: country,
          fba: fba,
          marketplaceTax: amountType == 'itemwithheldtax',
        );
      } else if (amountType.contains('fee') ||
          desc.contains('fee') ||
          desc.contains('commission') ||
          desc.contains('subscription')) {
        out.add(key, date, PlatformEntryKind.fee, amount);
      } else {
        out.add(key, date, PlatformEntryKind.other, amount);
      }
    }
    return out.build();
  }

  // ---------------------------------------------------------------- PayPal

  static PlatformImportFile _paypal(_Columns c, List<List<String>> rows) {
    final out = _Collector(PlatformFormat.paypalActivity);
    final monthFirst = _monthFirst(rows, c.index(_PayPal.date));
    for (final r in rows) {
      final status = normalizeHeader(c.get(r, _PayPal.status));
      if (status.isNotEmpty && !_isAny(status, _PayPal.completed)) continue;
      final currency = c.get(r, _PayPal.currency).trim().toUpperCase();
      if (currency.isNotEmpty && currency != 'EUR') {
        out.foreign++;
        continue;
      }
      final date = parsePlatformDate(
        c.get(r, _PayPal.date),
        monthFirst: monthFirst,
      );
      final gross = parseCents(c.get(r, _PayPal.gross));
      if (date == null || gross == null) {
        out.unreadable++;
        continue;
      }
      final fee = parseCents(c.get(r, _PayPal.fee)) ?? 0;
      final id = c.get(r, _PayPal.transactionId).trim();
      final key = id.isEmpty
          ? out.uniqueKey('row', [c.get(r, _PayPal.date), '$gross', '$fee'])
          : 'txn:$id';
      final type = normalizeHeader(c.get(r, _PayPal.type));
      if (gross < 0 && _containsAny(type, _PayPal.withdrawal)) {
        out.add(key, date, PlatformEntryKind.payout, gross);
      } else if (gross > 0 && !_containsAny(type, _PayPal.notSale)) {
        out.add(key, date, PlatformEntryKind.sale, gross, orderRef: key);
      } else if (gross < 0 && _containsAny(type, _PayPal.refund)) {
        out.add(key, date, PlatformEntryKind.refund, gross, orderRef: key);
      } else {
        out.add(key, date, PlatformEntryKind.other, gross);
      }
      if (fee != 0) out.add('$key:fee', date, PlatformEntryKind.fee, fee);
    }
    return out.build();
  }

  // ---------------------------------------------------------------- Stripe

  static PlatformImportFile _stripe(_Columns c, List<List<String>> rows) {
    final out = _Collector(PlatformFormat.stripeBalance);
    for (final r in rows) {
      final currency = c.get(r, _Stripe.currency).trim().toUpperCase();
      if (currency.isNotEmpty && currency != 'EUR') {
        out.foreign++;
        continue;
      }
      final date = parsePlatformDate(c.get(r, _Stripe.created));
      final gross = parseCents(c.get(r, _Stripe.gross));
      if (date == null || gross == null) {
        out.unreadable++;
        continue;
      }
      final fee = parseCents(c.get(r, _Stripe.fee)) ?? 0;
      final id = c.get(r, _Stripe.id).trim();
      final key = 'txn:$id';
      final category = normalizeHeader(c.get(r, _Stripe.category));
      switch (category) {
        case 'charge' || 'payment':
          out.add(key, date, PlatformEntryKind.sale, gross, orderRef: key);
        case 'refund' || 'paymentrefund' || 'refundfailure':
          out.add(key, date, PlatformEntryKind.refund, gross, orderRef: key);
        case 'payout' || 'payoutreversal' || 'transfer':
          out.add(key, date, PlatformEntryKind.payout, gross);
        case 'fee' || 'stripefee' || 'applicationfee' || 'tax':
          // Gebührenzeile: Betrag steht in „gross“, Stripe-Gebühr ggf. 0.
          out.add(key, date, PlatformEntryKind.fee, gross);
        default:
          out.add(key, date, PlatformEntryKind.other, gross);
      }
      // Stripe weist die Gebühr positiv aus; sie mindert das Guthaben.
      if (fee != 0) {
        out.add('$key:fee', date, PlatformEntryKind.fee, -fee.abs());
      }
    }
    return out.build();
  }

  // --------------------------------------------------------------- Shopify

  static PlatformImportFile _shopifyPayouts(
    _Columns c,
    List<List<String>> rows,
  ) {
    final out = _Collector(PlatformFormat.shopifyPayouts);
    final payouts = <String, (DateTime, int)>{};
    for (final r in rows) {
      final currency = c.get(r, _Shop.currency).trim().toUpperCase();
      if (currency.isNotEmpty && currency != 'EUR') {
        out.foreign++;
        continue;
      }
      final date = parsePlatformDate(c.get(r, _Shop.transactionDate));
      final amount = parseCents(c.get(r, _Shop.amount));
      if (date == null || amount == null) {
        out.unreadable++;
        continue;
      }
      final fee = parseCents(c.get(r, _Shop.fee)) ?? 0;
      final net = parseCents(c.get(r, _Shop.net)) ?? amount - fee;
      final order = c.get(r, _Shop.order).trim();
      final type = normalizeHeader(c.get(r, _Shop.type));
      final payoutId = c.get(r, _Shop.payoutId).trim();
      final key = out.uniqueKey('payout:$payoutId', [
        type,
        order,
        c.get(r, _Shop.transactionDate),
        c.get(r, _Shop.amount),
      ]);
      if (type == 'charge' || type == 'sale') {
        // Gleiche Kennung wie im Bestellexport, damit dieselbe Bestellung
        // nicht doppelt als Umsatz zählt.
        final saleKey = order.isEmpty ? key : 'order:$order';
        out.add(saleKey, date, PlatformEntryKind.sale, amount, orderRef: order);
      } else if (type == 'refund') {
        out.add(key, date, PlatformEntryKind.refund, amount, orderRef: order);
      } else {
        out.add(key, date, PlatformEntryKind.other, amount);
      }
      if (fee != 0) out.add('$key:fee', date, PlatformEntryKind.fee, -fee);
      if (payoutId.isNotEmpty) {
        final payoutDate =
            parsePlatformDate(c.get(r, _Shop.payoutDate)) ?? date;
        final previous = payouts[payoutId];
        payouts[payoutId] = (payoutDate, (previous?.$2 ?? 0) + net);
      }
    }
    for (final MapEntry(key: id, value: (date, sum)) in payouts.entries) {
      if (sum != 0) {
        out.add('payout:$id', date, PlatformEntryKind.payout, -sum);
      }
    }
    return out.build();
  }

  static PlatformImportFile _shopifyOrders(
    _Columns c,
    List<List<String>> rows,
  ) {
    final out = _Collector(PlatformFormat.shopifyOrders);
    for (final r in rows) {
      // Bestellexport: eine Zeile je Artikel, Summen nur in der ersten.
      final totalRaw = c.get(r, _Shop.total);
      if (totalRaw.trim().isEmpty) continue;
      final status = normalizeHeader(c.get(r, _Shop.financialStatus));
      if (!const {'paid', 'partiallyrefunded', 'refunded'}.contains(status)) {
        continue;
      }
      final currency = c.get(r, _Shop.currency).trim().toUpperCase();
      if (currency.isNotEmpty && currency != 'EUR') {
        out.foreign++;
        continue;
      }
      final date = parsePlatformDate(c.get(r, _Shop.paidAt));
      final total = parseCents(totalRaw);
      if (date == null || total == null) {
        out.unreadable++;
        continue;
      }
      final order = c.get(r, _Shop.name).trim();
      final country = c.get(r, _Shop.shippingCountry).trim().toUpperCase();
      out.add(
        'order:$order',
        date,
        PlatformEntryKind.sale,
        total,
        tax: parseCents(c.get(r, _Shop.taxes)) ?? 0,
        orderRef: order,
        country: country.length == 2 ? country : null,
      );
      final refunded = parseCents(c.get(r, _Shop.refundedAmount)) ?? 0;
      if (refunded != 0) {
        out.add(
          'order:$order:refund',
          date,
          PlatformEntryKind.refund,
          -refunded.abs(),
          orderRef: order,
          country: country.length == 2 ? country : null,
        );
      }
    }
    return out.build();
  }

  // ---------------------------------------------------------------- Hilfen

  /// Schrägstrich-Datum: Monat zuerst nur, wenn eine Zeile es beweist
  /// (zweite Zahl > 12); sonst Tag zuerst wie in Europa üblich.
  static bool _monthFirst(List<List<String>> rows, int? column) {
    if (column == null) return false;
    for (final r in rows) {
      if (column >= r.length) continue;
      final m = RegExp(r'^(\d{1,2})/(\d{1,2})/').firstMatch(r[column].trim());
      if (m == null) continue;
      if (int.parse(m[1]!) > 12) return false;
      if (int.parse(m[2]!) > 12) return true;
    }
    return false;
  }

  static bool _isAny(String value, Set<String> options) =>
      options.contains(value);

  static bool _containsAny(String value, List<String> parts) =>
      parts.any(value.contains);

  static bool _isAdvertising(String v) => _containsAny(v, const [
    'advertising',
    'werbung',
    'werbekosten',
    'publicite',
    'pubblicita',
    'publicidad',
    'sponsoredproducts',
  ]);

  static bool _isFee(String v) => _containsAny(v, const [
    'fee',
    'gebuhr',
    'frais',
    'commission',
    'tarifa',
    'costi',
    'subscription',
    'abonnement',
  ]);

  static const _nonEuroMarketplaces = {'GB', 'US', 'PL', 'SE', 'TR', 'CZ'};

  /// Marktplatz → Bestimmungsland (Näherung für die OSS-Warnung).
  static String? _marketplaceCountry(String raw) {
    final m = RegExp(
      r'amazon\.(com\.be|com\.tr|co\.uk|com|[a-z]{2})',
    ).firstMatch(raw.toLowerCase());
    if (m == null) return null;
    return switch (m[1]) {
      'com.be' => 'BE',
      'co.uk' => 'GB',
      'com' => 'US',
      'com.tr' => 'TR',
      'se' => 'SE',
      final tld => tld!.toUpperCase(),
    };
  }
}

class _Collector {
  _Collector(this.format);

  final PlatformFormat format;
  final entries = <PlatformEntry>[];
  final _seen = <String, int>{};
  int foreign = 0;
  int unreadable = 0;

  /// Kennung aus Prüfsumme; gleiche Zeilen in einer Datei werden durchgezählt.
  String uniqueKey(String prefix, List<String> parts) {
    final base = '$prefix:${fnv1a(parts.map((p) => p.trim()).join('|'))}';
    final n = (_seen[base] ?? 0) + 1;
    _seen[base] = n;
    return n == 1 ? base : '$base#$n';
  }

  void add(
    String id,
    DateTime date,
    PlatformEntryKind kind,
    int cents, {
    int tax = 0,
    String orderRef = '',
    String? country,
    bool fba = false,
    bool marketplaceTax = false,
  }) {
    if (cents == 0 && kind != PlatformEntryKind.sale) return;
    entries.add(
      PlatformEntry(
        externalId: id,
        date: date,
        kind: kind,
        amount: Money(cents),
        tax: Money(tax),
        orderRef: orderRef,
        destinationCountry: country,
        fulfilledByPlatform: fba,
        marketplaceCollectedTax: marketplaceTax,
      ),
    );
  }

  PlatformImportFile build() => PlatformImportFile(
    format: format,
    entries: List.unmodifiable(entries),
    skippedForeignCurrency: foreign,
    skippedUnreadable: unreadable,
  );
}

/// Spaltenzugriff über normalisierte Namen; fehlende Spalten liefern ''.
class _Columns {
  _Columns(List<String> header)
    : _index = {
        for (var i = header.length - 1; i >= 0; i--)
          normalizeHeader(header[i]): i,
      };

  final Map<String, int> _index;

  int? index(List<String> aliases) {
    for (final a in aliases) {
      final i = _index[a];
      if (i != null) return i;
    }
    return null;
  }

  bool has(List<String> aliases) => index(aliases) != null;

  String get(List<String> row, List<String> aliases) {
    final i = index(aliases);
    if (i == null || i >= row.length) return '';
    return row[i];
  }
}

/// Amazon Seller Central. Transaktionsbericht (Berichte → Zahlungen →
/// Datumsbereichsberichte) in DE/EN/FR/IT/ES; Abrechnung Flatfile V2
/// (Spaltennamen immer englisch, Tabulator).
abstract final class _Amz {
  static const date = [
    'datetime',
    'datumuhrzeit',
    'dateheure',
    'dataora',
    'fechayhora',
  ];
  static const settlementId = [
    'settlementid',
    'abrechnungsnummer',
    'numerodeversement',
    'numeropagamento',
    'identificadordepago',
  ];
  static const type = ['type', 'typ', 'tipo'];
  static const orderId = [
    'orderid',
    'bestellnummer',
    'numerodelacommande',
    'numeroordine',
    'numerodepedido',
  ];
  static const sku = ['sku'];
  static const description = [
    'description',
    'beschreibung',
    'descrizione',
    'descripcion',
  ];
  static const marketplace = ['marketplace', 'webdeamazon', 'sitoweb'];
  static const fulfillment = [
    'fulfillment',
    'fulfilment',
    'versand',
    'traitement',
    'gestione',
    'gestionlogistica',
  ];
  static const productSales = [
    'productsales',
    'umsatze',
    'ventesdeproduits',
    'vendite',
    'ventasdeproductos',
  ];
  static const salesColumns = [
    productSales,
    [
      'shippingcredits',
      'gutschriftfurversandkosten',
      'creditsdexpedition',
      'accreditiperlespedizioni',
      'abonosdeenvio',
    ],
    [
      'giftwrapcredits',
      'gutschriftfurgeschenkverpackung',
      'creditssurlemballagecadeau',
      'accreditiperconfezioniregalo',
      'abonosdeenvoltoriopararegalo',
    ],
    [
      'promotionalrebates',
      'rabatteauswerbeaktionen',
      'rabaispromotionnels',
      'scontipromozionali',
      'devolucionespromocionales',
    ],
  ];
  static const taxColumns = [
    [
      'productsalestax',
      'produktumsatzsteuer',
      'taxessurlaventedesproduits',
      'impostasullevenditedeiprodotti',
      'impuestodeventasdeproductos',
    ],
    [
      'shippingcreditstax',
      'steueraufversandgutschrift',
      'taxesurlescreditsdexpedition',
      'impostaaccreditiperlespedizioni',
      'impuestosporabonosdeenvio',
    ],
    [
      'giftwrapcreditstax',
      'steueraufgeschenkverpackungsgutschriften',
      'taxessurlescreditscadeaux',
      'impostasuicrediticonfezioneregalo',
      'impuestosporabonosdeenvoltoriopararegalo',
    ],
    [
      'promotionalrebatestax',
      'steueraufaktionsrabatte',
      'taxessurlesremisespromotionnelles',
      'impostasugliscontipromozionali',
      'impuestosdedevolucionespromocionales',
    ],
  ];
  static const withheldTax = [
    'marketplacewithheldtax',
    'einbehaltenesteueraufmarketplace',
    'taxesretenuessurlesitedevente',
    'trattenutaivadelmarketplace',
    'impuestoretenidoenelsitioweb',
  ];
  static const feeColumns = [
    [
      'sellingfees',
      'verkaufsgebuhren',
      'fraisdevente',
      'commissionidivendita',
      'tarifasdeventa',
    ],
    [
      'fbafees',
      'gebuhrenzuversanddurchamazon',
      'fraisexpedieparamazon',
      'costidelserviziologisticadiamazon',
      'tarifasdelogisticadeamazon',
    ],
    [
      'othertransactionfees',
      'anderetransaktionsgebuhren',
      'fraissurautrestransactions',
      'altricostirelativiallatransazioni',
      'tarifasdeotrastransacciones',
    ],
  ];
  static const other = ['other', 'andere', 'autre', 'altro', 'otro'];
  static const total = ['total', 'gesamt', 'totale'];

  static const orderTypes = {
    'order',
    'bestellung',
    'commande',
    'ordine',
    'pedido',
  };
  static const refundTypes = {
    'refund',
    'erstattung',
    'remboursement',
    'rimborso',
    'reembolso',
  };
  static const transferTypes = {
    'transfer',
    'ubertrag',
    'transfert',
    'trasferimento',
    'transferir',
    'transferencia',
  };

  // Flatfile V2
  static const totalAmount = ['totalamount'];
  static const depositDate = ['depositdate'];
  static const currency = ['currency'];
  static const transactionType = ['transactiontype'];
  static const amountType = ['amounttype'];
  static const amountDescription = ['amountdescription'];
  static const amount = ['amount'];
  static const postedDate = ['posteddate'];
  static const marketplaceName = ['marketplacename'];
  static const fulfillmentId = ['fulfillmentid'];
}

/// PayPal „Aktivitäten“ → Berichte → Aktivitätendownload (CSV).
abstract final class _PayPal {
  static const date = ['datum', 'date', 'fecha', 'data'];
  static const type = ['typ', 'type', 'tipo'];
  static const status = ['status', 'statut', 'stato', 'estado'];
  static const currency = ['wahrung', 'currency', 'devise', 'valuta', 'divisa'];
  static const gross = [
    'brutto',
    'gross',
    'avantcommission',
    'brut',
    'lordo',
    'bruto',
  ];
  static const fee = ['gebuhr', 'fee', 'commission', 'tariffa', 'comision'];
  static const net = ['netto', 'net', 'neto'];
  static const transactionId = [
    'transaktionscode',
    'transactionid',
    'numerodetransaction',
    'codicetransazione',
    'iddetransaccion',
    'iddelatransaccion',
  ];
  static const completed = {
    'abgeschlossen',
    'completed',
    'termine',
    'completata',
    'completado',
  };
  static const withdrawal = [
    'abbuchung',
    'withdrawal',
    'retrait',
    'prelievo',
    'retirada',
    'bankuberweisung',
    'transfertobank',
  ];
  static const notSale = [
    'bankgutschrift',
    'deposit',
    'wahrungsumrechnung',
    'currencyconversion',
    'ruckbuchung',
    'reversal',
    'einbehalt',
    'hold',
  ];
  static const refund = [
    'ruckzahlung',
    'erstattung',
    'refund',
    'remboursement',
    'rimborso',
    'reembolso',
  ];
}

/// Stripe Dashboard → Saldo → Exportieren (Saldo-Transaktionen, Variante
/// „Itemized“ mit reporting_category oder klassisch mit type).
abstract final class _Stripe {
  static const id = ['balancetransactionid', 'id'];
  static const category = ['reportingcategory', 'type'];
  static const created = ['createdutc', 'created', 'createddateutc'];
  static const gross = ['gross', 'amount'];
  static const fee = ['fee'];
  static const currency = ['currency'];
}

/// Shopify: Finanzen → Auszahlungen → Transaktionen exportieren bzw.
/// Bestellungen → Exportieren.
abstract final class _Shop {
  static const transactionDate = ['transactiondate'];
  static const type = ['type'];
  static const order = ['order'];
  static const payoutId = ['payoutid'];
  static const payoutDate = ['payoutdate'];
  static const amount = ['amount'];
  static const fee = ['fee'];
  static const net = ['net'];
  static const currency = ['currency'];
  static const name = ['name'];
  static const financialStatus = ['financialstatus'];
  static const paidAt = ['paidat'];
  static const total = ['total'];
  static const taxes = ['taxes'];
  static const refundedAmount = ['refundedamount'];
  static const shippingCountry = ['shippingcountry'];
}
