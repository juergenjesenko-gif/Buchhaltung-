import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../services/licensing/license_policy.dart';
import '../../widgets/primary_action_bar.dart';
import '../licensing/subscription_screen.dart';

/// Hinweisblatt der Demo (FA-13.14): erscheint statt jedes Speicherns,
/// Sendens, Teilens oder Exportierens. „Abo wählen“ als 56-dp-Knopf unten in
/// der Daumenzone, „Weiter ansehen“ darunter mit 12 dp Abstand.
Future<void> showDemoSheet(BuildContext context, {Feature? feature}) async {
  final state = AppScope.read(context);
  final choice = await showModalBottomSheet<_DemoChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DemoSheet(
      sharing:
          feature == Feature.dataExport ||
          feature == Feature.pdfSending ||
          feature == Feature.dunningSending,
      fromSettings: state.demoFromSettings,
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case _DemoChoice.subscribe:
      await openPaywall(context);
    case _DemoChoice.leave:
      await state.leaveDemo();
    case null:
    case _DemoChoice.stay:
      break;
  }
}

/// Abo-Seite öffnen (aus Banner, Blatt, Startauswahl).
Future<void> openPaywall(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()));

enum _DemoChoice { subscribe, stay, leave }

class DemoSheet extends StatelessWidget {
  const DemoSheet({super.key, this.sharing = false, this.fromSettings = false});

  /// Teilen/Senden/Export statt Speichern.
  final bool sharing;

  /// Demo aus den Einstellungen (mit Abo): „Demo beenden“ statt „Abo wählen“.
  final bool fromSettings;

  static const savedText =
      'In der Demo wird nichts gespeichert. Mit einem Abo wäre das jetzt '
      'gebucht.';
  static const sharedText =
      'In der Demo wird nichts gesendet, geteilt oder exportiert. PDFs der '
      'Demo tragen das Wasserzeichen „MUSTER – DEMO“.';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Demo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            sharing ? sharedText : savedText,
            key: const Key('demo-sheet-text'),
          ),
          const SizedBox(height: 16),
          if (fromSettings)
            PrimaryActionBar.filled(
              key: const Key('demo-sheet-leave'),
              label: 'Demo beenden',
              icon: Icons.logout,
              onPressed: () => Navigator.of(context).pop(_DemoChoice.leave),
            )
          else
            PrimaryActionBar.filled(
              key: const Key('demo-sheet-subscribe'),
              label: 'Abo wählen',
              icon: Icons.workspace_premium_outlined,
              onPressed: () => Navigator.of(context).pop(_DemoChoice.subscribe),
            ),
          const SizedBox(height: 12),
          PrimaryActionBar.outlined(
            key: const Key('demo-sheet-stay'),
            label: 'Weiter ansehen',
            icon: Icons.visibility_outlined,
            onPressed: () => Navigator.of(context).pop(_DemoChoice.stay),
          ),
        ],
      ),
    ),
  );
}
