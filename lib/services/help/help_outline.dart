import 'help_index.dart';

/// Gliederung der Hilfe (FA-11.1): erst die Kapitel (`##`), darin die
/// Abschnitte (`###` bzw. Fragen). Statt alles auf einmal sieht die
/// Nutzerin zuerst eine kurze Themenliste.
class HelpChapter {
  const HelpChapter({required this.title, this.intro, required this.sections});

  /// Kapitelüberschrift ohne Nummer, z. B. „Belege erfassen“.
  final String title;

  /// Text direkt unter der Kapitelüberschrift, vor dem ersten Abschnitt.
  final HelpSection? intro;

  /// Unterabschnitte in Handbuchreihenfolge.
  final List<HelpSection> sections;

  HelpTopic get topic =>
      HelpSection(title: title, chapter: title, body: '').topic;
}

/// Fasst die Abschnitte aus [parseManual] zu Kapiteln zusammen, in
/// Handbuchreihenfolge. „Inhalt“ liefert [parseManual] schon nicht.
List<HelpChapter> helpOutline(List<HelpSection> sections) {
  final order = <String>[];
  final intro = <String, HelpSection>{};
  final subs = <String, List<HelpSection>>{};
  for (final s in sections) {
    if (!subs.containsKey(s.chapter)) {
      order.add(s.chapter);
      subs[s.chapter] = [];
    }
    if (s.title == s.chapter && !intro.containsKey(s.chapter)) {
      intro[s.chapter] = s;
    } else {
      subs[s.chapter]!.add(s);
    }
  }
  return [
    for (final c in order)
      HelpChapter(title: c, intro: intro[c], sections: subs[c]!),
  ];
}

/// Kapitel, in das ein Hilfe-Knopf mit [topic] direkt springt; `null` für
/// allgemeine Hilfe (dann die Übersicht).
HelpChapter? chapterForTopic(List<HelpChapter> outline, HelpTopic? topic) {
  if (topic == null || topic == HelpTopic.general) return null;
  for (final c in outline) {
    if (c.topic == topic) return c;
  }
  return null;
}
