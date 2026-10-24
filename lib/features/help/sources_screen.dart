import 'package:flutter/material.dart';

import '../../domain/official_sources.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/source_link.dart';

/// „Quellen & Rechtsgrundlagen“: amtliche Quellen als antippbare Links und
/// der Hinweis „kein Angebot einer Behörde“ (Google-Play-Vorgabe, Ablehnung
/// 2026-10-24). Erreichbar aus der Hilfe und aus Einstellungen → Rechtliches.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static const title = 'Quellen & Rechtsgrundlagen';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Kein Angebot einer Behörde',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(OfficialSource.disclaimer),
            ),
            for (final s in OfficialSource.all)
              ListTile(
                key: Key('source-${s.url}'),
                minTileHeight: 56,
                leading: const Icon(Icons.open_in_new),
                title: Text(s.label),
                subtitle: Text(s.url, maxLines: 2),
                onTap: () => openSource(context, s.url),
              ),
          ],
        ),
      ),
    );
  }
}
