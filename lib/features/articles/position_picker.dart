import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/article.dart';
import '../../domain/invoice.dart';

/// Öffnet die Auswahl aus Artikeln und früher verwendeten Positionen
/// (L-11.5, FA-5.45). Ein Tipp übernimmt die Position; alles bleibt danach
/// in der Position änderbar. `null` = abgebrochen.
Future<InvoiceItem?> pickPosition(BuildContext context) async {
  final suggestions = await AppScope.read(
    context,
  ).repositories.articles.suggestions();
  if (!context.mounted) return null;
  return showModalBottomSheet<InvoiceItem>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => PositionPickerSheet(suggestions: suggestions),
  );
}

class PositionPickerSheet extends StatefulWidget {
  const PositionPickerSheet({super.key, required this.suggestions});

  final List<PositionSuggestion> suggestions;

  @override
  State<PositionPickerSheet> createState() => _PositionPickerSheetState();
}

class _PositionPickerSheetState extends State<PositionPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final hits = widget.suggestions.where((s) => s.matches(_query)).toList();
    return SafeArea(
      child: Padding(
        // Tastatur schiebt die Liste nach oben; Suchfeld unten, im
        // Daumenbereich (L-0.6).
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Position übernehmen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (widget.suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Noch keine Artikel und keine früheren Positionen. Lege '
                  'Artikel unter Rechnungen → Artikel an, oder tippe die '
                  'Position frei ein.',
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in hits)
                      ListTile(
                        key: Key('suggestion-${s.description}'),
                        minTileHeight: 56,
                        leading: Icon(
                          s.isArticle
                              ? Icons.inventory_2_outlined
                              : Icons.history,
                        ),
                        title: Text(
                          s.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (s.article?.number.isNotEmpty ?? false)
                              s.article!.number,
                            '${Fmt.money(s.unitPrice)} netto je ${s.unit}',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.of(context).pop(s.toItem()),
                      ),
                  ],
                ),
              ),
            if (widget.suggestions.length > 5) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('positionSearch'),
                decoration: const InputDecoration(
                  labelText: 'Suchen (Bezeichnung oder Artikelnummer)',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
