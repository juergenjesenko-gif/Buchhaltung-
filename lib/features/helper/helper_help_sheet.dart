import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../widgets/common.dart';
import 'helper_pair_screen.dart';

/// Kurze Erklärung „Was ist ein Mithelfer-Gerät?“ (FA-17.13).
const helperHelpTitle = 'Was ist ein Mithelfer-Gerät?';

const helperHelpPoints = <(IconData, String)>[
  (
    Icons.photo_camera_outlined,
    'Ein zweites Handy, z. B. von Familie oder Team, das nur Belege '
        'fotografiert und an dein Hauptgerät sendet.',
  ),
  (
    Icons.block,
    'Es bucht nichts, sieht keine Buchhaltung, keine Rechnungen und keine '
        'Auswertungen. Gebucht wird nur auf dem Hauptgerät mit „Übernehmen“.',
  ),
  (
    Icons.lock_outline,
    'Jeder Beleg reist verschlüsselt (AES-256). Den Schlüssel tauschen die '
        'Geräte nur beim Koppeln über den QR-Code aus – der Anbieter und der '
        'Mailanbieter sehen nur Datensalat.',
  ),
  (
    Icons.mail_outline,
    'Standardweg ist E-Mail: Das Mithelfer-Gerät sendet aus seinem eigenen '
        'Postfach an die Empfangsadresse des Hauptgeräts. Alternativ ein '
        'gemeinsamer Cloud-Ordner oder Teilen.',
  ),
  (
    Icons.link_off,
    'Trennen geht jederzeit auf dem Hauptgerät unter Einstellungen → '
        'Mithelfer-Geräte.',
  ),
];

Future<void> showHelperHelpSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            key: const Key('helper-help-sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                helperHelpTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final (icon, text) in helperHelpPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              FilledButton(
                key: const Key('helper-help-close'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Verstanden'),
              ),
            ],
          ),
        ),
      ),
    );

/// „?“-Knopf neben „Gerät koppeln“ / „Gerät hinzufügen“, 48 dp.
class HelperHelpButton extends StatelessWidget {
  const HelperHelpButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('helper-help'),
    tooltip: helperHelpTitle,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: () => showHelperHelpSheet(context),
    icon: const Icon(Icons.help_outline),
  );
}

/// Einstellungen eines Hauptgeräts → „Als Mithelfer-Gerät koppeln“
/// (FA-17.13): nur auf einer Installation ohne Belege und Rechnungen, und
/// nur nach Bestätigung, weil das Gerät danach keine Buchhaltung mehr zeigt.
Future<void> becomeHelperDevice(BuildContext context) async {
  final state = AppScope.read(context);
  if (await state.hasBookkeepingData()) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nicht auf diesem Gerät'),
        content: const Text(
          'Hier sind schon Belege oder Rechnungen gespeichert. Ein '
          'Mithelfer-Gerät führt keine eigene Buchhaltung. Koppel lieber ein '
          'anderes Handy – oder sichere deine Daten und setze die App zurück.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Zum Mithelfer-Gerät machen?'),
      content: const Text(
        'Dieses Gerät zeigt danach nur noch die Belegerfassung für das '
        'gekoppelte Hauptgerät. Deine Stammdaten bleiben gespeichert, sind '
        'aber nicht mehr sichtbar, bis du die Kopplung aufhebst.',
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('become-helper-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Weiter zum Koppeln'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const HelperPairScreen()));
  if (context.mounted && !AppScope.read(context).isHelperDevice) {
    showSnack(context, 'Nicht gekoppelt – alles bleibt wie es war.');
  }
}
