/// Branche, Beschreibung und Kategorie eines Belegs vorschlagen (L-2.20).
///
/// Datengetrieben: bekannte Ketten und Schlüsselwörter je Branche stehen in
/// Tabellen; jede Branche nennt eine der Startkategorien
/// (`AppDatabase.seedCategories`). Alles ist ein Vorschlag, den die Nutzerin
/// bestätigt; fehlt die Kategorie (umbenannt, gelöscht), wird keine gewählt.
library;

import 'receipt_text_parser.dart';

enum ReceiptBranch {
  supermarket('Lebensmittel', 'Sonstige Ausgaben'),
  drugstore('Drogerie', 'Sonstige Ausgaben'),
  fuel('Treibstoff', 'Kfz-Kosten'),
  toll('Maut', 'Kfz-Kosten'),
  parking('Parken', 'Kfz-Kosten'),
  taxi('Taxi', 'Reisekosten'),
  transport('Fahrkarte', 'Reisekosten'),
  hotel('Übernachtung', 'Reisekosten'),
  // Bewirtung (FA-2.60): Kategorie mit Abzugsbeschränkung, nur Vorschlag.
  restaurant('Bewirtung', 'Bewirtung'),
  office('Büromaterial', 'Büromaterial'),
  electronics('Elektronik', 'Büromaterial'),
  postal('Porto', 'Büromaterial'),
  telecom('Telefon/Internet', 'Telefon & Internet'),
  books('Fachliteratur', 'Fortbildung & Fachliteratur'),
  // Baumarkt: Startkategorie „Material und Werkzeug“ (Entscheidung
  // Auftraggeberin 2026-10-17). Möbel, Sport: „Sonstige Ausgaben“.
  hardware('Baumarkt-Einkauf', 'Material und Werkzeug'),
  furniture('Einrichtung', 'Sonstige Ausgaben'),
  retail('Einkauf', 'Sonstige Ausgaben');

  const ReceiptBranch(this.label, this.category);

  /// Beschreibung, wenn keine Artikelzeile erkannt wurde („Maut“).
  final String label;

  /// Name der vorgeschlagenen Startkategorie.
  final String category;
}

/// Bekannte Ketten: Schreibweise auf dem Beleg (klein, nur Buchstaben und
/// Ziffern), Anzeigename, Branche.
const receiptChains = <(String, String, ReceiptBranch)>[
  ('spar', 'SPAR', ReceiptBranch.supermarket),
  ('eurospar', 'EUROSPAR', ReceiptBranch.supermarket),
  ('interspar', 'INTERSPAR', ReceiptBranch.supermarket),
  ('billa', 'BILLA', ReceiptBranch.supermarket),
  ('billaplus', 'BILLA PLUS', ReceiptBranch.supermarket),
  ('hofer', 'HOFER', ReceiptBranch.supermarket),
  ('aldi', 'ALDI', ReceiptBranch.supermarket),
  ('lidl', 'Lidl', ReceiptBranch.supermarket),
  ('penny', 'PENNY', ReceiptBranch.supermarket),
  ('mpreis', 'MPREIS', ReceiptBranch.supermarket),
  ('unimarkt', 'Unimarkt', ReceiptBranch.supermarket),
  ('rewe', 'REWE', ReceiptBranch.supermarket),
  ('edeka', 'EDEKA', ReceiptBranch.supermarket),
  ('kaufland', 'Kaufland', ReceiptBranch.supermarket),
  ('netto', 'Netto', ReceiptBranch.supermarket),
  ('mercator', 'Mercator', ReceiptBranch.supermarket),
  ('tus', 'Tuš', ReceiptBranch.supermarket),
  ('konzum', 'Konzum', ReceiptBranch.supermarket),
  ('dm', 'dm', ReceiptBranch.drugstore),
  ('bipa', 'BIPA', ReceiptBranch.drugstore),
  ('rossmann', 'Rossmann', ReceiptBranch.drugstore),
  ('mueller', 'Müller', ReceiptBranch.drugstore),
  ('omv', 'OMV', ReceiptBranch.fuel),
  ('bp', 'BP', ReceiptBranch.fuel),
  ('shell', 'Shell', ReceiptBranch.fuel),
  ('eni', 'Eni', ReceiptBranch.fuel),
  ('agip', 'Eni', ReceiptBranch.fuel),
  ('avanti', 'Avanti', ReceiptBranch.fuel),
  ('turmol', 'Turmöl', ReceiptBranch.fuel),
  ('turmoel', 'Turmöl', ReceiptBranch.fuel),
  ('jet', 'JET', ReceiptBranch.fuel),
  ('aral', 'Aral', ReceiptBranch.fuel),
  ('esso', 'Esso', ReceiptBranch.fuel),
  ('petrol', 'Petrol', ReceiptBranch.fuel),
  ('unox', 'Uno-X', ReceiptBranch.fuel),
  ('unoxmobility', 'Uno-X Mobility', ReceiptBranch.fuel),
  ('asfinag', 'ASFINAG', ReceiptBranch.toll),
  ('dars', 'DARS d.d.', ReceiptBranch.toll),
  ('darsdd', 'DARS d.d.', ReceiptBranch.toll),
  ('ikea', 'IKEA', ReceiptBranch.office),
  ('libro', 'Libro', ReceiptBranch.office),
  ('pagro', 'Pagro', ReceiptBranch.office),
  ('mediamarkt', 'MediaMarkt', ReceiptBranch.electronics),
  ('saturn', 'Saturn', ReceiptBranch.electronics),
  ('amazon', 'Amazon', ReceiptBranch.office),
  ('post', 'Post', ReceiptBranch.postal),
  ('osterreichischepost', 'Österreichische Post', ReceiptBranch.postal),
  ('deutschepost', 'Deutsche Post', ReceiptBranch.postal),
  ('thalia', 'Thalia', ReceiptBranch.books),
  ('oebb', 'ÖBB', ReceiptBranch.transport),
  ('obb', 'ÖBB', ReceiptBranch.transport),
  ('db', 'Deutsche Bahn', ReceiptBranch.transport),
  ('a1', 'A1', ReceiptBranch.telecom),
  ('merkur', 'Merkur', ReceiptBranch.supermarket),
  ('muller', 'Müller', ReceiptBranch.drugstore),
  ('bauhaus', 'BAUHAUS', ReceiptBranch.hardware),
  ('obi', 'OBI', ReceiptBranch.hardware),
  ('hornbach', 'Hornbach', ReceiptBranch.hardware),
  ('hagebau', 'hagebau', ReceiptBranch.hardware),
  ('hagebaumarkt', 'hagebau', ReceiptBranch.hardware),
  ('lagerhaus', 'Lagerhaus', ReceiptBranch.hardware),
  ('toom', 'toom', ReceiptBranch.hardware),
  ('xxxlutz', 'XXXLutz', ReceiptBranch.furniture),
  ('mobelix', 'Möbelix', ReceiptBranch.furniture),
  ('moebelix', 'Möbelix', ReceiptBranch.furniture),
  ('kika', 'kika', ReceiptBranch.furniture),
  ('leiner', 'Leiner', ReceiptBranch.furniture),
  ('action', 'Action', ReceiptBranch.retail),
  ('tedi', 'TEDi', ReceiptBranch.retail),
  ('kik', 'KiK', ReceiptBranch.retail),
  ('hervis', 'Hervis', ReceiptBranch.retail),
  ('intersport', 'Intersport', ReceiptBranch.retail),
  ('decathlon', 'Decathlon', ReceiptBranch.retail),
  ('magenta', 'Magenta', ReceiptBranch.telecom),
];

/// Schlüsselwörter je Branche (mehrsprachig, klein). Ein Treffer irgendwo
/// auf dem Beleg genügt; die erste Branche der Liste mit Treffer gilt.
const _branchWords = <(ReceiptBranch, List<String>)>[
  // Taxi vor Maut: Taxiquittungen nennen oft die Mautgebühr („Toll“).
  (ReceiptBranch.taxi, ['taxi', 'fare', 'taxameter']),
  (
    ReceiptBranch.toll,
    [
      'maut', 'mautticket', 'vignette', 'vinjeta', 'cestnina', 'toll', //
      'cestarina', 'pedaggio', 'peaje', 'péage', 'myto', 'autópálya',
      'alpenstrasse', 'alpenstraße', 'hochalpenstraße',
    ],
  ),
  (ReceiptBranch.parking, ['parken', 'parkgebühr', 'parking', 'parkiranje']),
  (
    ReceiptBranch.fuel,
    [
      'diesel', 'benzin', 'super 95', 'super plus', 'liter', 'litre', //
      'pumpe', 'zapfsäule', 'tankstelle', 'gorivo', 'carburante', 'brændstof',
    ],
  ),
  (ReceiptBranch.hotel, ['hotel', 'übernachtung', 'nächtigung', 'zimmer']),
  (
    ReceiptBranch.restaurant,
    [
      'restaurant', 'gasthaus', 'gasthof', 'wirtshaus', 'ristorante', //
      'trattoria', 'pizzeria', 'osteria', 'brasserie', 'bistro',
      'gastronomie', 'bewirtung', 'kellner', 'tisch nr', 'tisch:',
    ],
  ),
  (ReceiptBranch.transport, ['fahrkarte', 'ticket', 'bahn', 'zug']),
];

/// Vorschlag aus dem Belegtext. [description] ist höchstens
/// [maxDescriptionLength] Zeichen lang.
class ReceiptClassification {
  const ReceiptClassification({this.branch, this.description});

  final ReceiptBranch? branch;
  final String? description;

  /// Name der vorgeschlagenen Startkategorie, `null` wenn unklar.
  String? get categoryName => branch?.category;
}

const maxDescriptionLength = 40;

abstract final class ReceiptClassifier {
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ä', 'a')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Häufige OCR-Verwechslungen in Markennamen angleichen (0→o, 5→s, 1→l).
  static String ocrFold(String n) =>
      n.replaceAll('0', 'o').replaceAll('5', 's').replaceAll('1', 'l');

  /// Bekannte Kette als eigenes Wort irgendwo in der Zeile („BAUHAUS Depot
  /// GmbH, NL 797“, „Danke für Ihren Einkauf bei OBI“). Nur Marken ab vier
  /// Buchstaben, damit „dm“, „bp“ oder „Post“ nicht in Fließtext treffen.
  static (String, ReceiptBranch)? chainWordIn(String row) {
    final words = [
      for (final w in row.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)))
        if (w.isNotEmpty) ocrFold(_norm(w)),
    ];
    for (final (key, name, branch) in receiptChains) {
      if (key.length < 5 || _commonWords.contains(key)) continue;
      if (words.contains(key)) return (name, branch);
    }
    return null;
  }

  /// Marken, die auch gewöhnliche Wörter auf Belegen sind.
  static const _commonWords = {'netto', 'petrol', 'action', 'merkur'};

  /// Bekannte Kette in einer Kopfzeile, auch mit Logo-Rauschen am Wortende
  /// („SPARO“: Tannensymbol als O gelesen, „BILLA®“).
  static (String, ReceiptBranch)? chainIn(
    String row, {
    bool exactOnly = false,
  }) {
    final n = _norm(row);
    if (n.isEmpty) return null;
    final firstWord = _norm(row.trim().split(RegExp(r'\s+')).first);
    final nFold = ocrFold(n);
    final firstFold = ocrFold(firstWord);
    for (final (key, name, branch) in receiptChains) {
      if (n == key || (!exactOnly && firstWord == key)) {
        return (name, branch);
      }
      // OCR-Varianten („BAUHAU5“, „H0FER“) nur bei Marken ohne Ziffern.
      if (key.length >= 4 &&
          !RegExp(r'\d').hasMatch(key) &&
          (nFold == key || (!exactOnly && firstFold == key))) {
        return (name, branch);
      }
      // Logo-Rauschen: ein bis zwei angehängte O/0 an einer Marke in
      // Großbuchstaben.
      if (key.length >= 3 &&
          RegExp(r'^[A-Z0-9ÄÖÜ\-]+[O0®©™*]{1,2}\W*$').hasMatch(row.trim()) &&
          RegExp('^$key[o0]{1,2}\$').hasMatch(n)) {
        return (name, branch);
      }
    }
    return null;
  }

  static ReceiptClassification classify(
    List<String> rows,
    ReceiptScanResult result,
  ) {
    ReceiptBranch? branch;
    final merchant = result.merchant?.value;
    if (merchant != null) branch = chainIn(merchant)?.$2;
    final text = rows.join('\n').toLowerCase();
    if (branch == null) {
      for (final (b, words) in _branchWords) {
        if (words.any(
          (w) => RegExp(
            '(?<![\\p{L}])${RegExp.escape(w)}',
            unicode: true,
          ).hasMatch(text),
        )) {
          branch = b;
          break;
        }
      }
    }
    // Tankstelle, aber nur Shop-Artikel (Getränke, Pfand): kein Treibstoff,
    // also nicht Kfz-Kosten, sondern der Einkauf laut Artikeln (FA-2.62,
    // OMV-Beleg Gerätetest 0.23.1).
    if (branch == ReceiptBranch.fuel &&
        !rows.any((r) => fuelItem.hasMatch(r)) &&
        itemNames(rows).isNotEmpty) {
      branch = ReceiptBranch.retail;
    }
    return ReceiptClassification(
      branch: branch,
      description: _description(merchant, branch, rows),
    );
  }

  /// Treibstoff in einer Artikelzeile: Sorte oder Menge in Litern mit
  /// Literpreis („41,23 l x 1,659 EUR/l“).
  static final fuelItem = RegExp(
    r'diesel|\bsuper\b|eurosuper|super ?plus|benzin|adblue|\bliter\b|'
    r'\blitre\b|\bltr\b|maxxmotion|v-power|ultimate|\bbenzina\b|\bgorivo\b|'
    r'\d[,.]\d{1,3}\s?l\b|eur\s?/\s?l\b|€\s?/\s?l\b|/\s?ltr?\b',
    caseSensitive: false,
  );

  /// Was gekauft wurde, nicht bei wem (Gerätetest 0.22.2): erster Artikel
  /// plus „u. a.“, sonst die Branche („Maut“, „Baumarkt-Einkauf“), sonst
  /// `null`. Der Händlername steht im Feld Geschäftspartner und wird nie in
  /// die Beschreibung kopiert.
  static String? _description(
    String? merchant,
    ReceiptBranch? branch,
    List<String> rows,
  ) {
    final retail =
        branch == null ||
        const {
          ReceiptBranch.supermarket,
          ReceiptBranch.drugstore,
          ReceiptBranch.office,
          ReceiptBranch.electronics,
          ReceiptBranch.hardware,
          ReceiptBranch.furniture,
          ReceiptBranch.retail,
        }.contains(branch);
    final items = retail ? itemNames(rows) : const <String>[];
    final merchantNorm = _norm(merchant ?? '');
    final useful = [
      for (final i in items)
        if (merchantNorm.isEmpty || !merchantNorm.contains(_norm(i))) i,
    ];
    if (useful.isNotEmpty) {
      final suffix = useful.length > 1 ? ' u. a.' : '';
      var first = useful.first;
      final room = maxDescriptionLength - suffix.length;
      if (first.length > room) first = '${first.substring(0, room - 1)}…';
      return '$first$suffix';
    }
    return branch?.label;
  }

  /// Artikelbezeichnungen in Belegreihenfolge, bereinigt: ohne Menge
  /// („1 x“, „2 Stk“), Artikelnummer, Preis, Steuerkennzeichen und Kürzel
  /// in Großbuchstaben („SET 3L Lasurpinsel-S“ → „Lasurpinsel“). Nur Zeilen
  /// vor der Summe.
  static List<String> itemNames(List<String> rows) {
    final result = <String>[];
    for (final row in rows) {
      final t = row.trim();
      final lower = t.toLowerCase();
      // Spaltenkopf „ZP Artikel Bezeichnung Summe“ (OMV) ist kein Ende.
      if (_endOfItems.hasMatch(lower) &&
          (RegExp(r'\d[,.]\d{2}').hasMatch(t) ||
              t.split(RegExp(r'\s+')).length <= 2)) {
        break;
      }
      if (_noItemLine.hasMatch(lower)) continue;
      final price = _trailingPrice.firstMatch(t);
      String? raw;
      if (price != null) {
        raw = t.substring(0, price.start);
      } else if (RegExp(r'^[A-ZÄÖÜ0-9 ]{6,}$').hasMatch(t)) {
        // Supermarkt-Bon, Preise in eigener Spalte („SBUDGET BAGUETTE“).
        raw = t;
      }
      if (raw == null) continue;
      final name = cleanItem(raw);
      if (name != null && !result.contains(name)) result.add(name);
      if (result.length == 3) break;
    }
    return result;
  }

  static final _trailingPrice = RegExp(
    r'\s-?\d{1,5}[,.]\d{2}(?:\s*(?:€|eur))?(?:\s*[A-D*]{1,2})?\s*$',
    caseSensitive: false,
  );

  static final _endOfItems = RegExp(
    r'\b(summe|zwischensumme|gesamt|gesamtbetrag|gesamtsumme|endsumme|endbetrag|'
    r'rechnungsbetrag|total|zu zahlen|zahlbetrag|betrag)\b',
  );

  static final _noItemLine = RegExp(
    r'mwst|ust\b|uid|steuer|netto|brutto|rabatt|pfand|rückgeld|ruckgeld|'
    r'gegeben|bar\b|karte|visa|mastercard|maestro|debit|kontaktlos|'
    r'tel\b|tel\.|fax|www|@|datum|uhrzeit|kassa|kasse|bon\b|beleg|rechnung|'
    r'gmbh|\bag\b|\bkg\b|filiale|\bnl\b|straße|strasse|str\.|'
    r'^\s*[a-z]?-?\d{4,5}\s+\p{L}',
    unicode: true,
  );

  /// Bereinigt eine Artikelbezeichnung; `null`, wenn kein Wort ab vier
  /// Buchstaben übrig bleibt.
  static String? cleanItem(String raw) {
    final words = <String>[];
    // Kassenkürzel mit Punkten („VÖSL.MIN.0.KS“) in Wörter zerlegen.
    final spaced = raw.replaceAll(
      RegExp(r'(?<=\p{L})\.(?=[\p{L}\d])', unicode: true),
      ' ',
    );
    for (var w in spaced.trim().split(RegExp(r'\s+'))) {
      w = w.replaceAll(RegExp(r'^[^\p{L}]+|[^\p{L}]+$', unicode: true), '');
      // Abgeschnittenes Anhängsel „Lasurpinsel-S“.
      w = w.replaceFirst(RegExp(r'-\p{L}$', unicode: true), '');
      if (w.isEmpty) continue;
      if (RegExp(r'\d').hasMatch(w)) continue;
      final lower = w.toLowerCase();
      if (const {
        'x',
        'stk',
        'st',
        'stück',
        'kg',
        'pkg',
        'pck',
        'm',
        'l',
      }.contains(lower)) {
        continue;
      }
      if (_noItem.contains(w.toUpperCase())) continue;
      w = _abbreviations[w.toUpperCase()] ?? w;
      // Kürzel in Großbuchstaben („SET“, „BIO“) nur, wenn es Gemischtes gibt.
      words.add(w);
    }
    final mixed = words.any((w) => w != w.toUpperCase());
    final kept = [
      for (final w in words)
        if (!(mixed && w.length <= 3 && w == w.toUpperCase())) w,
    ];
    if (!kept.any((w) => RegExp(r'^\p{L}{4,}', unicode: true).hasMatch(w))) {
      return null;
    }
    if (!mixed) {
      // „SBUDGET BAGUETTE“ → „Baguette“: das längste Wort benennt die Ware.
      final w = kept.reduce((a, b) => b.length > a.length ? b : a);
      return w[0] + w.substring(1).toLowerCase();
    }
    final text = kept.join(' ');
    return text.length <= 40 ? text : '${text.substring(0, 39)}…';
  }

  /// Häufige Kassenkürzel, ausgeschrieben.
  static const _abbreviations = {
    'VÖSL': 'Vöslauer',
    'VOSL': 'Vöslauer',
    'MIN': 'Mineral',
    'MINW': 'Mineralwasser',
    'MINERALW': 'Mineralwasser',
  };

  static const _noItem = {
    'EUR', 'SUMME', 'GESAMT', 'BAR', 'KARTE', 'DEBIT', 'MASTERCARD', 'VISA', //
    'KONTAKTLOS', 'KUNDENBELEG', 'VERKAUF', 'DUPLIKAT', 'TOTAL', 'BUDGET',
    'FREEFROM', 'KASSA', 'MWST', 'UST',
  };
}
