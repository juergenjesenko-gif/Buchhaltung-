import '../../domain/money.dart';
import '../../domain/receipt.dart';
import 'receipt_scan_prefill.dart';

/// Was sich die App je Lieferant gemerkt hat (FA-2.50, Schema 20
/// `supplier_memory`). Nur Werte, die die Nutzerin beim Speichern bestätigt
/// hat; nichts verlässt das Gerät.
class LearnedSupplier {
  const LearnedSupplier({
    required this.counterparty,
    this.categoryId,
    this.vatPermille,
    this.currency = 'EUR',
    this.paymentMethod,
  });

  /// Gewählter Anzeigename („SPAR Österreich“ statt „SPARO 0STERREICH“).
  final String counterparty;
  final int? categoryId;
  final int? vatPermille;
  final String currency;
  final PaymentMethod? paymentMethod;
}

/// Ergebnis der Zusammenführung: Vorschlag samt der Felder, die aus dem
/// Gelernten stammen und „wie beim letzten Mal“ tragen.
class SupplierSuggestion {
  const SupplierSuggestion({
    required this.prefill,
    this.categoryId,
    this.paymentMethod,
    this.learnedFields = const {},
  });

  final ReceiptScanPrefill prefill;
  final int? categoryId;
  final PaymentMethod? paymentMethod;

  /// Formularfelder: `counterparty`, `category`, `vat`, `currency`, `payment`.
  final Set<String> learnedFields;
}

/// Lernen je Lieferant (FA-2.50, Lastenheft L-0.2, L-2.20).
///
/// Schlüssel: Richtung plus Aussteller-UID (`expense|UID:ATU12345678`) oder
/// normalisierter Name (`expense|NAME:spar`). Die UID ist eindeutig und geht
/// vor; der Name fängt Belege ohne UID (Kassenbon) ab.
class SupplierLearning {
  const SupplierLearning._();

  /// Rechtsformen und Füllwörter, die den Namen nicht unterscheiden.
  static const _noise = {
    'gmbh',
    'ag',
    'kg',
    'og',
    'eu',
    'ek',
    'gesmbh',
    'mbh',
    'co',
    'und',
    'se',
    'ug',
    'gbr',
    'ohg',
    'kgaa',
    'ltd',
    'inc',
    'srl',
    'doo',
    'sro',
    'filiale',
    'markt',
    'the',
  };

  /// Normalisierter Name: klein, Umlaute ohne Punkte (ö → o, wie OCR sie oft liest), nur Buchstaben und
  /// Ziffern, ohne Rechtsform. OCR-Verwechslungen 0/O werden angeglichen.
  /// Leer, wenn nichts Unterscheidendes übrig bleibt.
  static String normalizeName(String name) {
    var s = name.toLowerCase();
    const fold = {
      'ä': 'a',
      'ö': 'o',
      'ü': 'u',
      'ß': 'ss',
      'é': 'e',
      'è': 'e',
      'á': 'a',
      'à': 'a',
      'č': 'c',
      'š': 's',
      'ž': 'z',
      'ć': 'c',
    };
    fold.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final words = [
      for (final w in s.split(' '))
        if (w.isNotEmpty && !_noise.contains(w)) w.replaceAll('0', 'o'),
    ];
    return words.join(' ');
  }

  /// Normalisierte UID (ohne Leerzeichen und Punkte, groß); leer, wenn zu
  /// kurz für eine UID.
  static String normalizeVatId(String vatId) {
    final s = vatId.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return s.length < 8 ? '' : s;
  }

  /// Schlüssel für Nachschlagen und Merken, UID zuerst.
  static List<String> keys(
    BookingDirection direction, {
    String? vatId,
    String? name,
  }) {
    final out = <String>[];
    final uid = normalizeVatId(vatId ?? '');
    if (uid.isNotEmpty) out.add('${direction.name}|UID:$uid');
    final n = normalizeName(name ?? '');
    if (n.isNotEmpty) out.add('${direction.name}|NAME:$n');
    return out;
  }

  /// Führt Erkanntes und Gelerntes zusammen.
  ///
  /// - Name: immer der gelernte (Zuordnung OCR-Variante → gewählter Name).
  /// - Kategorie und Zahlungsart: immer gelernt; die Erkennung rät die
  ///   Kategorie nur aus der Branche, die Zahlungsart gar nicht.
  /// - Steuersatz: erkannt geht vor; gelernt nur, wenn kein Satz erkannt.
  /// - Währung: erkannt geht vor; gelernte Fremdwährung nur, wenn die
  ///   Erkennung keine sichere Währung fand ([currencyConfident] false) und
  ///   der Betrag sonst als Euro gälte.
  static SupplierSuggestion merge(
    ReceiptScanPrefill p,
    LearnedSupplier? learned, {
    required bool currencyConfident,
    required BookingDirection direction,
  }) {
    if (learned == null) return SupplierSuggestion(prefill: p);
    final fields = <String>{};

    String? counterparty = p.counterparty;
    if (learned.counterparty.isNotEmpty) {
      counterparty = learned.counterparty;
      fields.add('counterparty');
    }

    var vat = p.vatPermille;
    if (vat == null && p.vatParts.isEmpty && learned.vatPermille != null) {
      vat = learned.vatPermille;
      fields.add('vat');
    }

    var currency = p.currency;
    Money? gross = p.gross;
    Money? original = p.originalGross;
    if (!currencyConfident &&
        direction == BookingDirection.expense &&
        learned.currency != 'EUR' &&
        currency == 'EUR' &&
        original == null) {
      currency = learned.currency;
      original = gross;
      gross = null;
      fields.add('currency');
    }

    if (learned.categoryId != null) fields.add('category');
    if (learned.paymentMethod != null) fields.add('payment');

    return SupplierSuggestion(
      prefill: ReceiptScanPrefill(
        date: p.date,
        gross: gross,
        vatPermille: vat,
        counterparty: counterparty,
        documentNumber: p.documentNumber,
        issuerVatId: p.issuerVatId,
        currency: currency,
        originalGross: original,
        hints: p.hints,
        description: p.description,
        // Gelernte Kategorie ersetzt den Branchenvorschlag.
        categoryName: learned.categoryId == null ? p.categoryName : null,
        vatParts: p.vatParts,
        note: p.note,
        codeSource: p.codeSource,
        registerId: p.registerId,
        printedVat: p.printedVat,
      ),
      categoryId: learned.categoryId,
      paymentMethod: learned.paymentMethod,
      learnedFields: fields,
    );
  }
}
