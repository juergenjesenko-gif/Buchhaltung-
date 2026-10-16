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
  books('Fachliteratur', 'Fortbildung & Fachliteratur');

  const ReceiptBranch(this.label, this.category);

  /// Kurzbezeichnung in der Beschreibung („SPAR – Lebensmittel“).
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

const maxDescriptionLength = 60;

abstract final class ReceiptClassifier {
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ä', 'a')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Bekannte Kette in einer Kopfzeile, auch mit Logo-Rauschen am Wortende
  /// („SPARO“: Tannensymbol als O gelesen, „BILLA®“).
  static (String, ReceiptBranch)? chainIn(
    String row, {
    bool exactOnly = false,
  }) {
    final n = _norm(row);
    if (n.isEmpty) return null;
    final firstWord = _norm(row.trim().split(RegExp(r'\s+')).first);
    for (final (key, name, branch) in receiptChains) {
      if (n == key || (!exactOnly && firstWord == key)) {
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
    return ReceiptClassification(
      branch: branch,
      description: _description(merchant, branch, rows),
    );
  }

  /// „SPAR – Lebensmittel (Baguette, Biomilch)“; ohne Händler nur die
  /// Branche, ohne beides `null`.
  static String? _description(
    String? merchant,
    ReceiptBranch? branch,
    List<String> rows,
  ) {
    final head = [?merchant, ?branch?.label].join(' – ');
    if (head.isEmpty) return null;
    final items =
        branch == ReceiptBranch.supermarket ||
            branch == ReceiptBranch.drugstore ||
            branch == ReceiptBranch.office ||
            branch == ReceiptBranch.electronics
        ? _items(rows)
        : const <String>[];
    var text = head;
    for (var n = items.length; n > 0; n--) {
      final candidate = '$head (${items.take(n).join(', ')})';
      if (candidate.length <= maxDescriptionLength) {
        text = candidate;
        break;
      }
    }
    return text.length <= maxDescriptionLength
        ? text
        : '${text.substring(0, maxDescriptionLength - 1)}…';
  }

  /// Bis zu drei Artikelbezeichnungen: Zeilen aus Großbuchstaben mit
  /// mindestens einem Wort von 4 Buchstaben, ohne Betrag, ohne Schlüsselwort.
  static List<String> _items(List<String> rows) {
    final result = <String>[];
    for (final row in rows) {
      final t = row.trim();
      if (ReceiptTextParser.amounts(t).isNotEmpty) {
        // „SCHOKORULADE HIMBEERE 3,49 A“: Bezeichnung vor dem Betrag.
        final m = RegExp(r'^([A-ZÄÖÜ][A-ZÄÖÜ ]{5,}?)\s+\d').firstMatch(t);
        if (m == null) continue;
        _addItem(result, m.group(1)!);
      } else if (RegExp(r'^[A-ZÄÖÜ0-9 ]{6,}$').hasMatch(t)) {
        _addItem(result, t);
      }
      if (result.length == 3) break;
    }
    return result;
  }

  static const _noItem = {
    'EUR', 'SUMME', 'GESAMT', 'BAR', 'KARTE', 'DEBIT', 'MASTERCARD', 'VISA', //
    'KONTAKTLOS', 'KUNDENBELEG', 'VERKAUF', 'DUPLIKAT', 'TOTAL', 'BUDGET',
    'FREEFROM', 'KASSA', 'MWST', 'UST',
  };

  static void _addItem(List<String> result, String raw) {
    final words = [
      for (final w in raw.split(RegExp(r'\s+')))
        if (w.length >= 4 &&
            RegExp(r'^[A-ZÄÖÜ]+$').hasMatch(w) &&
            !_noItem.contains(w))
          w,
    ];
    if (words.isEmpty) return;
    // „SBUDGET BAGUETTE“ → „Baguette“: das längste Wort benennt die Ware.
    final w = words.reduce((a, b) => b.length > a.length ? b : a);
    final item = w[0] + w.substring(1).toLowerCase();
    if (!result.contains(item)) result.add(item);
  }
}
