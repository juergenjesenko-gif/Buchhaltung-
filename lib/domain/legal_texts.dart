import 'country.dart';

/// Texte, die die Nutzerin bei der ersten Einrichtung bestätigt (Lastenheft
/// L-17.1 bis L-17.4, L-17.12). Jede wesentliche Änderung bekommt eine neue
/// [version]; die App holt die Bestätigung dann erneut ein.
///
/// Die Fassungen sind **Entwürfe**: Nutzungsbedingungen und
/// Datenschutzerklärung erstellt bzw. prüft vor dem Release eine Anwältin
/// (L-17.11, Spezifikation Abschnitt 14, P-L1).
class LegalText {
  const LegalText({
    required this.kind,
    required this.version,
    required this.title,
    required this.summary,
    required this.confirmation,
  });

  final String kind;
  final String version;
  final String title;
  final String summary;
  final String confirmation;

  /// L-17.1/L-17.2: eigenständig, von den Nutzungsbedingungen getrennt.
  static const disclaimer = LegalText(
    kind: 'disclaimer',
    version: '2026-10-12',
    title: 'Keine Steuerberatung',
    summary:
        'Diese App ist ein Werkzeug für dein eigenes Büro. Sie rechnet und '
        'bereitet vor, prüft aber nichts steuerrechtlich und ersetzt keine '
        'Steuerberatung. Für deine Buchhaltung und deine Steuererklärungen '
        'bist du selbst verantwortlich; lass sie von einer Steuerberatung '
        'prüfen.',
    confirmation:
        'Ich habe verstanden, dass die App Informationen bereitstellt, sie '
        'aber nicht steuerrechtlich prüft, und dass die Prüfung durch eine '
        'Steuerberatung erforderlich bleibt.',
  );

  static const terms = LegalText(
    kind: 'terms',
    version: '2026-10-12-entwurf',
    title: 'Nutzungsbedingungen und Datenschutz',
    summary:
        'Deine Daten bleiben auf deinem Gerät; der Anbieter erhält sie nicht. '
        'Daten verlassen das Gerät nur, wenn du teilst, eine Sicherung '
        'anlegst oder eine UID-Nummer prüfen lässt. Nutzungsbedingungen und '
        'Datenschutzerklärung im Volltext findest du auf der Produktseite und '
        'in den Einstellungen.',
    confirmation:
        'Ich akzeptiere die Nutzungsbedingungen und habe die '
        'Datenschutzerklärung zur Kenntnis genommen.',
  );

  static const all = [disclaimer, terms];
}

/// Volltexte im Menü „Rechtliches“ (L-22.18, Store-Pflicht). Eine Quelle:
/// `docs/legal/*.md` werden unverändert als Asset eingebunden;
/// `test/legal_documents_test.dart` prüft, dass jede Datei im `pubspec.yaml`
/// steht.
enum LegalDocument {
  imprint('Impressum', 'docs/legal/IMPRESSUM.md'),
  privacy('Datenschutzerklärung', 'docs/legal/DATENSCHUTZ.md'),
  terms('Nutzungsbedingungen', 'docs/legal/NUTZUNGSBEDINGUNGEN.md');

  const LegalDocument(this.title, this.asset);
  final String title;
  final String asset;

  /// `false`, solange P-L1 (anwaltliche Prüfung) offen ist. Dann zeigt die
  /// App über jedem Text den Vermerk „Entwurf“ (Testbuild). Vor dem
  /// Store-Build wird P-L1 erledigt, der Vermerk in den Dateien entfernt und
  /// dieser Wert auf `true` gesetzt; `test/legal_documents_test.dart` hält
  /// Wert und Dateien gleich (Spezifikation FA-11.5, P-L20).
  static const reviewed = false;

  /// Text ohne den einleitenden Entwurfs-Blockzitatblock der Datei; den
  /// Vermerk setzt die App selbst einheitlich darüber.
  static String body(String markdown) {
    final lines = markdown.split('\n');
    final out = <String>[];
    var skipping = false;
    var headingSeen = false;
    for (final line in lines) {
      if (!headingSeen && line.startsWith('# ')) {
        headingSeen = true;
        skipping = true;
        continue;
      }
      if (skipping && (line.startsWith('>') || line.trim().isEmpty)) continue;
      skipping = false;
      out.add(line);
    }
    return out.join('\n').trim();
  }

  /// Markierungen für Länder-Abschnitte in `docs/legal/*.md`. HTML-Kommentare,
  /// damit die Datei als Markdown lesbar bleibt.
  static final _open = RegExp(r'^\s*<!--\s*nur\s+(AT|DE)\s*-->\s*$');
  static final _close = RegExp(r'^\s*<!--\s*/nur\s*-->\s*$');

  /// Filtert den Text nach Land (Rückmeldung Tester: nur die Normen des
  /// eigenen Landes zeigen). Abschnitte des anderen Landes fallen weg, die
  /// Markierungen selbst werden entfernt. Ohne [country] (noch kein Profil,
  /// etwa in der Ersteinrichtung) bleiben alle Abschnitte stehen.
  ///
  /// Markierungen stehen je auf einer eigenen Zeile und dürfen nicht
  /// verschachtelt werden. Ist die Struktur fehlerhaft (verschachtelt,
  /// unbalanciert), wird nichts weggelassen: lieber zu viel Text als still
  /// verschluckter Vertragstext. Prüfbar über [countryMarkupValid].
  static String forCountry(String markdown, Country? country) {
    if (!countryMarkupValid(markdown)) return markdown;
    final out = <String>[];
    String? section;
    for (final line in markdown.split('\n')) {
      final open = _open.firstMatch(line);
      if (open != null) {
        section = open.group(1);
        continue;
      }
      if (_close.hasMatch(line)) {
        section = null;
        continue;
      }
      if (section == null || country == null || section == country.code) {
        out.add(line);
      }
    }
    return out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  /// `true`, wenn jede Länder-Markierung geschlossen und keine verschachtelt
  /// ist.
  static bool countryMarkupValid(String markdown) {
    var inside = false;
    for (final line in markdown.split('\n')) {
      if (_open.hasMatch(line)) {
        if (inside) return false;
        inside = true;
      } else if (_close.hasMatch(line)) {
        if (!inside) return false;
        inside = false;
      } else if (line.contains('<!--') && line.contains('nur')) {
        // Tippfehler in einer Markierung (z. B. „nur CH“) nicht übergehen.
        return false;
      }
    }
    return !inside;
  }
}
