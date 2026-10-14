import 'dart:math' as math;

/// Hilfe Stufe 1 (FA-11.1): Volltextsuche im Benutzerhandbuch, offline, ohne
/// Server. Quelle ist ausschließlich `docs/BENUTZERHANDBUCH.md`, das als
/// Asset eingebunden ist – es gibt keinen zweiten Hilfetext.

/// Thema eines Abschnitts, für den Kontextbezug (vom Belegformular geöffnet
/// stehen Beleg-Themen vorn).
enum HelpTopic { general, receipts, invoices }

/// Ein durchsuchbarer Abschnitt: eine `##`/`###`-Überschrift samt Text, oder
/// eine fett gesetzte Frage aus „Häufige Fragen“ bzw. „Wenn etwas nicht geht“.
class HelpSection {
  const HelpSection({
    required this.title,
    required this.chapter,
    required this.body,
  });

  /// Überschrift bzw. Frage, ohne Markdown-Zeichen.
  final String title;

  /// Kapitelüberschrift (`## …`), zu der der Abschnitt gehört.
  final String chapter;

  /// Markdown-Text des Abschnitts ohne die Überschriftzeile.
  final String body;

  HelpTopic get topic {
    final c = normalizeHelpText(chapter);
    if (c.contains('beleg')) return HelpTopic.receipts;
    if (c.contains('rechnung') || c.contains('kunden')) {
      return HelpTopic.invoices;
    }
    return HelpTopic.general;
  }

  /// Klartext-Auszug für die Trefferliste.
  String excerpt([int maxLength = 160]) {
    final plain = stripMarkdown(body).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (plain.length <= maxLength) return plain;
    final cut = plain.lastIndexOf(' ', maxLength);
    return '${plain.substring(0, cut > 40 ? cut : maxLength)} …';
  }
}

class HelpHit {
  const HelpHit(this.section, this.score);
  final HelpSection section;
  final double score;
}

/// Kapitel, deren fett gesetzte Absätze je ein eigener Treffer sind.
const _faqChapters = ['haufige fragen', 'wenn etwas nicht geht'];

/// Zerlegt das Handbuch in Abschnitte. Inhaltsverzeichnis und Titel werden
/// übersprungen; leere Abschnitte ebenso.
List<HelpSection> parseManual(String markdown) {
  final sections = <HelpSection>[];
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  var chapter = '';
  String? title;
  var buffer = <String>[];
  var inFence = false;

  void flush() {
    final t = title;
    if (t == null) return;
    final body = buffer.join('\n').trim();
    buffer = <String>[];
    final norm = normalizeHelpText(t);
    if (norm == 'inhalt') return;
    if (_faqChapters.any(norm.contains)) {
      _splitFaq(chapter, body, sections);
      return;
    }
    if (stripMarkdown(body).trim().isEmpty) return;
    sections.add(HelpSection(title: t, chapter: chapter, body: body));
  }

  for (final line in lines) {
    if (line.trimLeft().startsWith('```')) inFence = !inFence;
    final h = inFence ? null : RegExp(r'^(#{2,3})\s+(.*)$').firstMatch(line);
    if (h != null) {
      flush();
      final text = _cleanHeading(h.group(2)!);
      if (h.group(1)!.length == 2) chapter = text;
      title = text;
      continue;
    }
    if (title != null && line.trim() != '---') buffer.add(line);
  }
  flush();
  return sections;
}

String _cleanHeading(String raw) =>
    stripMarkdown(raw).replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();

void _splitFaq(String chapter, String body, List<HelpSection> out) {
  final paragraphs = body.split(RegExp(r'\n\s*\n'));
  String? intro;
  for (final p in paragraphs) {
    final text = p.trim();
    if (text.isEmpty) continue;
    final m = RegExp(r'^\*\*(.+?)\*\*').firstMatch(text);
    if (m == null) {
      // Fortsetzung des vorigen Eintrags oder Einleitung.
      if (out.isNotEmpty && out.last.chapter == chapter && intro == null) {
        final last = out.removeLast();
        out.add(
          HelpSection(
            title: last.title,
            chapter: chapter,
            body: '${last.body}\n\n$text',
          ),
        );
      } else {
        intro = text;
      }
      continue;
    }
    intro = null;
    final question = stripMarkdown(
      m.group(1)!,
    ).replaceAll(RegExp(r'[„“"]'), '').trim();
    out.add(HelpSection(title: question, chapter: chapter, body: text));
  }
}

/// Entfernt die Markdown-Auszeichnung, die das Handbuch verwendet.
String stripMarkdown(String s) => s
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'[*_`]'), '')
    .replaceAll(RegExp(r'^\s*[-|>]+\s?', multiLine: true), '')
    .replaceAll('|', ' ');

/// Kleinbuchstaben, Umlaute und ß ausgeschrieben-gleich, Satzzeichen weg.
String normalizeHelpText(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

const _stopwords = {
  'der',
  'die',
  'das',
  'den',
  'dem',
  'des',
  'ein',
  'eine',
  'einen',
  'einem',
  'einer',
  'und',
  'oder',
  'ich',
  'du',
  'wie',
  'was',
  'wo',
  'wann',
  'warum',
  'kann',
  'ist',
  'mit',
  'mein',
  'meine',
  'meinen',
  'zu',
  'im',
  'in',
  'an',
  'auf',
  'fur',
  'von',
  'es',
  'nicht',
  'man',
  'bei',
  'auch',
  'so',
  'sich',
  'wird',
  'werden',
  'hat',
  'habe',
  'mich',
  'mir',
  'dir',
  'dich',
  'als',
  'am',
};

/// Einfache deutsche Stammformbildung: häufige Endungen abschneiden.
String stemGerman(String word) {
  var w = word;
  for (final suffix in const [
    'ungen',
    'ung',
    'heiten',
    'heit',
    'keiten',
    'keit',
    'ern',
    'en',
    'er',
    'es',
    'e',
    'n',
    's',
  ]) {
    if (w.length - suffix.length >= 4 && w.endsWith(suffix)) {
      w = w.substring(0, w.length - suffix.length);
      break;
    }
  }
  return w;
}

/// Synonyme in Stammform: Frage-Wort → Wörter, die das Handbuch verwendet.
const _synonyms = <String, List<String>>{
  'losch': ['storni', 'storno'],
  'loschen': ['storni', 'storno'],
  'entfern': ['storni', 'losch'],
  'ruckgang': ['storni'],
  'kaputt': ['fehl'],
  'geht': ['fehl'],
  'fehler': ['fehl'],
  'rechnung': ['rechnung'],
  'quittung': ['beleg'],
  'kassenbon': ['beleg'],
  'bon': ['beleg'],
  'foto': ['fotografi', 'seit'],
  'kamera': ['fotografi'],
  'scann': ['auslesen', 'fotografi'],
  'mwst': ['umsatzsteu'],
  'mehrwertsteu': ['umsatzsteu'],
  'ust': ['umsatzsteu'],
  'backup': ['sicherung'],
  'sichern': ['sicherung'],
  'steuerberat': ['kanzlei', 'export'],
  'handy': ['gerat', 'telefon'],
  'kleinunternehmergrenz': ['kleinunternehm', 'umsatzgrenz', 'grenz'],
  'grenz': ['kleinunternehm', 'umsatzgrenz'],
  'wahrung': ['fremd', 'kurs'],
  'dollar': ['wahrung', 'kurs'],
  'passwort': ['sperr'],
  'pin': ['sperr'],
};

/// Wortstämme eines Textes, ohne Füllwörter.
List<String> helpTokens(String text) => [
  for (final w in normalizeHelpText(text).split(' '))
    if (w.length > 1 && !_stopwords.contains(w)) stemGerman(w),
];

/// BM25-Index über die Handbuchabschnitte. Überschriften zählen dreifach.
class HelpIndex {
  HelpIndex(this.sections) {
    for (final s in sections) {
      final tokens = [
        ...helpTokens(s.title),
        ...helpTokens(s.title),
        ...helpTokens(s.title),
        ...helpTokens(s.chapter),
        ...helpTokens(stripMarkdown(s.body)),
      ];
      final tf = <String, int>{};
      for (final t in tokens) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      _tf.add(tf);
      _len.add(tokens.length);
      for (final t in tf.keys) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    _avgLen = _len.isEmpty
        ? 1
        : _len.reduce((a, b) => a + b) / _len.length.toDouble();
  }

  factory HelpIndex.fromManual(String markdown) =>
      HelpIndex(parseManual(markdown));

  final List<HelpSection> sections;
  final _tf = <Map<String, int>>[];
  final _len = <int>[];
  final _df = <String, int>{};
  late final double _avgLen;

  static const _k1 = 1.2;
  static const _b = 0.75;

  /// Gewicht für Synonym-Treffer gegenüber dem wörtlichen Begriff.
  static const _synonymWeight = 0.6;

  double _idf(String term) {
    final df = _df[term] ?? 0;
    final n = sections.length;
    return math.log(1 + (n - df + 0.5) / (df + 0.5));
  }

  /// Treffer absteigend nach Relevanz. Mit [context] werden Abschnitte des
  /// passenden Themas leicht bevorzugt; ohne Suchbegriff stehen sie vorn.
  List<HelpHit> search(String query, {HelpTopic? context, int limit = 20}) {
    final terms = <String, double>{};
    for (final t in helpTokens(query)) {
      terms[t] = 1;
      for (final s in _synonyms[t] ?? const <String>[]) {
        terms.putIfAbsent(s, () => _synonymWeight);
      }
    }
    final hits = <HelpHit>[];
    for (var i = 0; i < sections.length; i++) {
      var score = 0.0;
      if (terms.isEmpty) {
        if (context != null && sections[i].topic == context) score = 1;
      } else {
        for (final e in terms.entries) {
          final f = _matchFrequency(i, e.key);
          if (f == 0) continue;
          final norm =
              f * (_k1 + 1) / (f + _k1 * (1 - _b + _b * _len[i] / _avgLen));
          score += e.value * _idf(e.key) * norm;
        }
        if (score > 0 && context != null && sections[i].topic == context) {
          score *= 1.3;
        }
      }
      if (score > 0) hits.add(HelpHit(sections[i], score));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  /// Häufigkeit eines Stamms; zusammengesetzte Wörter („Kleinunternehmer-
  /// regelung“) zählen über Präfix-Treffer mit, ab vier Zeichen.
  int _matchFrequency(int i, String term) {
    final tf = _tf[i];
    final exact = tf[term] ?? 0;
    if (exact > 0 || term.length < 4) return exact;
    var sum = 0;
    for (final e in tf.entries) {
      if (e.key.startsWith(term)) sum += e.value;
    }
    return sum;
  }
}
