import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/help/help_index.dart';
import '../../services/help/help_outline.dart';
import '../../services/help/support_mail.dart';
import '../../widgets/adaptive.dart';
import '../../app_state.dart';
import '../../services/booking_rule_templates.dart';
import '../../widgets/primary_action_bar.dart';
import '../booking_rules/booking_rules_screen.dart';
import 'sources_screen.dart';

/// Asset-Pfad des Handbuchs. Das Handbuch selbst ist das Asset (pubspec.yaml),
/// es gibt keine Kopie.
const manualAsset = 'docs/BENUTZERHANDBUCH.md';

/// Hilfe-Symbol für die AppBar der Hauptbildschirme (FA-11.1). Oben rechts,
/// weil unten rechts die Erfassungsknöpfe liegen und Hilfe selten gebraucht
/// wird – sie darf außerhalb der Daumenzone liegen (DESIGN_SPEC 4).
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, this.context});

  final HelpTopic? context;

  @override
  Widget build(BuildContext buildContext) => IconButton(
    tooltip: 'Hilfe',
    icon: const Icon(Icons.help_outline),
    onPressed: () => Navigator.of(
      buildContext,
    ).push(MaterialPageRoute(builder: (_) => HelpScreen(context: context))),
  );
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.context, this.manual, this.launcher});

  /// Bildschirm, von dem aus die Hilfe geöffnet wurde.
  final HelpTopic? context;

  /// Für Tests: Handbuchtext statt Asset.
  final String? manual;

  final SupportMailLauncher? launcher;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static HelpIndex? _cached;
  HelpIndex? _index;
  final _query = TextEditingController();

  SupportMailLauncher get _launcher =>
      widget.launcher ?? const SupportMailLauncher();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final HelpIndex index;
    if (widget.manual != null) {
      index = HelpIndex.fromManual(widget.manual!);
    } else {
      index = _cached ??= HelpIndex.fromManual(
        await rootBundle.loadString(manualAsset),
      );
    }
    if (!mounted) return;
    setState(() => _index = index);
    // Hilfe-Knopf mit Thema: direkt ins passende Kapitel, zurück führt in
    // die Übersicht.
    final chapter = chapterForTopic(
      helpOutline(index.sections),
      widget.context,
    );
    if (chapter == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HelpChapterScreen(chapter: chapter)),
      );
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _mailSupport() async {
    final version = await _launcher.appVersion();
    final uri = supportMailUri(supportSubject(version, _query.text));
    final opened = await _launcher.openMail(uri);
    if (opened || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keine Mail-App gefunden'),
        content: const SelectableText(
          'Schreib uns bitte an $supportAddress. Gib dabei die App-Version '
          'an (Einstellungen).',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: supportAddress));
              Navigator.of(context).pop();
            },
            child: const Text('Adresse kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final noQuery = _query.text.trim().isEmpty;
    final hits = noQuery
        ? <HelpHit>[]
        : index?.search(_query.text, context: widget.context) ?? [];
    final outline = index == null
        ? <HelpChapter>[]
        : helpOutline(index.sections);
    return Scaffold(
      appBar: AppBar(title: const Text('Hilfe')),
      body: ReadableWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Frag mich etwas …',
                  hintText:
                      'z. B. Beleg stornieren, Rückseite, '
                      'Kleinunternehmergrenze',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: index == null
                  ? const Center(child: CircularProgressIndicator())
                  : noQuery
                  ? ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final c in outline)
                          ListTile(
                            minTileHeight: 56,
                            title: Text(c.title),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HelpChapterScreen(chapter: c),
                              ),
                            ),
                          ),
                        ListTile(
                          key: const Key('help-sources'),
                          minTileHeight: 56,
                          leading: const Icon(Icons.gavel_outlined),
                          title: const Text(SourcesScreen.title),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SourcesScreen(),
                            ),
                          ),
                        ),
                      ],
                    )
                  : hits.isEmpty
                  ? _NoHit(onMail: _mailSupport)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final hit in hits)
                          ListTile(
                            title: Text(hit.section.title),
                            subtitle: Text(
                              '${hit.section.chapter == hit.section.title ? '' : '${hit.section.chapter} · '}'
                              '${hit.section.excerpt()}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    HelpSectionScreen(section: hit.section),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextButton.icon(
                            icon: const Icon(Icons.mail_outline),
                            label: const Text('Nicht dabei? Support fragen'),
                            onPressed: _mailSupport,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoHit extends StatelessWidget {
  const _NoHit({required this.onMail});
  final VoidCallback onMail;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Dazu steht nichts im Handbuch.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Versuch es mit einem anderen Wort – oder schreib uns. Die Mail-App '
        'öffnet sich mit vorausgefülltem Betreff; es wird nichts angehängt, '
        'du entscheidest, was du schickst.',
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          icon: const Icon(Icons.mail_outline),
          label: const Text('E-Mail an den Support'),
          onPressed: onMail,
        ),
      ),
    ],
  );
}

/// Ein Handbuchkapitel: Einleitung, darunter die Abschnitte zum Aufklappen
/// (ganze Zeile tippbar, mindestens 56 dp hoch).
class HelpChapterScreen extends StatelessWidget {
  const HelpChapterScreen({super.key, required this.chapter});
  final HelpChapter chapter;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(chapter.title)),
    body: ReadableWidth(
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            if (chapter.intro != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: markdownBlocks(context, chapter.intro!.body),
                ),
              ),
            for (final s in chapter.sections)
              ExpansionTile(
                title: Text(s.title),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...markdownBlocks(context, s.body),
                  // Hilfeartikel mit Vorlage (FA-20.6).
                  if (templateForHelpTitle(s.title) case final t?)
                    FilledButton.icon(
                      key: Key('help-create-rule-${s.title}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.rule),
                      label: const Text('Regel anlegen'),
                      onPressed: () => openBookingRule(
                        context,
                        template: t.build(
                          AppScope.read(context).categories,
                          DateTime.now(),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

/// Ein Handbuchabschnitt, lesbar dargestellt. Kleiner eigener Markdown-
/// Darsteller statt eines Pakets: das Handbuch nutzt nur Absätze, Listen,
/// Fett/Kursiv, Code und Tabellen.
class HelpSectionScreen extends StatelessWidget {
  const HelpSectionScreen({super.key, required this.section});
  final HelpSection section;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(section.chapter)),
    // Hilfeartikel mit Vorlage (FA-20.6): ein Tipp füllt die Regel vor.
    bottomNavigationBar: switch (templateForHelpTitle(section.title)) {
      null => null,
      final t => PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('help-create-rule'),
          label: 'Regel anlegen',
          icon: Icons.rule,
          onPressed: () => openBookingRule(
            context,
            template: t.build(
              AppScope.read(context).categories,
              DateTime.now(),
            ),
          ),
        ),
      ),
    },
    body: ReadableWidth(
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (section.title != section.chapter)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ...markdownBlocks(context, section.body),
          ],
        ),
      ),
    ),
  );
}

/// Zerlegt Markdown in Absätze, Listenpunkte und Tabellenzeilen.
List<Widget> markdownBlocks(BuildContext context, String markdown) {
  final theme = Theme.of(context).textTheme;
  final out = <Widget>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    out.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(inlineMarkdown(paragraph.join(' '), theme.bodyLarge)),
      ),
    );
    paragraph.clear();
  }

  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    final list = RegExp(r'^(\s*)([-*]|\d+\.)\s+(.*)$').firstMatch(line);
    if (line.trim().isEmpty) {
      flush();
    } else if (line.startsWith('#')) {
      flush();
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            stripMarkdown(line.replaceFirst(RegExp(r'^#+\s*'), '')),
            style: theme.titleMedium,
          ),
        ),
      );
    } else if (line.trimLeft().startsWith('|')) {
      flush();
      if (RegExp(r'^\s*\|[\s:|-]+\|\s*$').hasMatch(line)) continue;
      final cells = line
          .trim()
          .replaceAll(RegExp(r'^\||\|$'), '')
          .split('|')
          .map((c) => c.trim())
          .join('  ·  ');
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(inlineMarkdown(cells, theme.bodyMedium)),
        ),
      );
    } else if (list != null) {
      flush();
      final marker = list.group(2)!;
      out.add(
        Padding(
          padding: EdgeInsets.only(
            left: 8.0 + list.group(1)!.length * 4,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(marker == '-' || marker == '*' ? '•' : marker),
              ),
              Expanded(
                child: Text.rich(
                  inlineMarkdown(list.group(3)!, theme.bodyLarge),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (out.isNotEmpty && paragraph.isEmpty && raw.startsWith('   ')) {
      // Fortsetzung eines Listenpunkts – an den vorigen Text hängen wäre
      // aufwendig; als eingerückte Zeile ist es gut lesbar.
      out.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 6),
          child: Text.rich(inlineMarkdown(line.trim(), theme.bodyLarge)),
        ),
      );
    } else {
      paragraph.add(line.trim().replaceFirst(RegExp(r'^>\s?'), ''));
    }
  }
  flush();
  return out;
}

/// Fett (`**`), kursiv (`*`/`_`), Code (`` ` ``) und Links (nur Text).
TextSpan inlineMarkdown(String text, TextStyle? base) {
  final cleaned = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1)!,
  );
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|(?<![\w*])[*_]([^*_]+)[*_]');
  var pos = 0;
  for (final m in pattern.allMatches(cleaned)) {
    if (m.start > pos) {
      spans.add(TextSpan(text: cleaned.substring(pos, m.start)));
    }
    if (m.group(1) != null) {
      spans.add(
        TextSpan(
          text: m.group(1)!.replaceAll(RegExp(r'[*_`]'), ''),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else if (m.group(2) != null) {
      spans.add(
        TextSpan(
          text: m.group(2),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: m.group(3),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    pos = m.end;
  }
  if (pos < cleaned.length) spans.add(TextSpan(text: cleaned.substring(pos)));
  return TextSpan(style: base, children: spans);
}
