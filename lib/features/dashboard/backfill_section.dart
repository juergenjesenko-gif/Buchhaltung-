import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../services/turnover_basis.dart';

/// Teil der Umsatz-/Kleinunternehmerkarte: geschätzter Umsatz vor dem
/// App-Start und Nachtragen der Rechnungen davor (FA-4.16).
///
/// UX-Instanz: Knöpfe volle Breite bzw. je halbe Breite, mindestens 48 dp,
/// 12 dp Abstand; „Ja, vollständig“ rechts im Daumenbereich, rückgängig im
/// Firmenprofil – daher keine zusätzliche Rückfrage.
class BackfillSection extends StatelessWidget {
  const BackfillSection({
    super.key,
    required this.status,
    required this.askComplete,
    required this.onBackfill,
    required this.onConfirm,
    required this.onLater,
  });

  final BackfillStatus status;

  /// Frage „Sind alle Rechnungen … erfasst?“ zeigen (nicht nach „Später“).
  final bool askComplete;

  final VoidCallback onBackfill;
  final VoidCallback onConfirm;
  final VoidCallback onLater;

  static String question(BackfillStatus status) =>
      'Du hast ${Fmt.money(status.backfilled)} von geschätzten '
      '${Fmt.money(status.estimate)} nachgetragen. Sind alle Rechnungen vor '
      'dem ${Fmt.date(status.trackingStart!)} erfasst?';

  static const replacedText =
      'Schätzung ersetzt durch nachgetragene Rechnungen';

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final rest = status.currentYearRest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!rest.isZero) ...[
          const SizedBox(height: 8),
          Text(
            'davon ${Fmt.money(rest)} geschätzt vor App-Start',
            key: const Key('backfill-estimate'),
            style: small,
          ),
        ],
        if (status.replacedByBackfill) ...[
          const SizedBox(height: 8),
          Text(replacedText, key: const Key('backfill-replaced'), style: small),
        ],
        if (askComplete) ...[
          const SizedBox(height: 12),
          Text(
            question(status),
            key: const Key('backfill-question'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('backfill-later'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onLater,
                  child: const Text('Später'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('backfill-confirm'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onConfirm,
                  child: const Text('Ja, vollständig'),
                ),
              ),
            ],
          ),
        ],
        if (status.canBackfill) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('backfill-start'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onBackfill,
            icon: const Icon(Icons.history_outlined, size: 20),
            label: const Text('Rechnungen vor dem App-Start nachtragen'),
          ),
        ],
      ],
    );
  }
}
