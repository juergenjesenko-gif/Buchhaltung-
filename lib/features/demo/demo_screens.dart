import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_state.dart';
import '../../services/demo/demo_session.dart';
import '../../services/licensing/license_policy.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import 'demo_sheet.dart';

/// Dokumentenordner für die Demo-Belegbilder; Tests setzen einen
/// Ersatzordner.
Future<Directory> Function() demoDocumentsDir =
    getApplicationDocumentsDirectory;

/// Demo starten (FA-13.14): Muster-Datenbank frisch anlegen und anzeigen.
/// [fromSettings]: aus Einstellungen → „Demo ansehen“.
Future<void> startDemo(
  BuildContext context, {
  bool fromSettings = false,
}) async {
  final state = AppScope.read(context);
  Navigator.of(context).popUntil((r) => r.isFirst);
  final dir = await demoDocumentsDir();
  final db = await DemoSession.open(documentsDir: dir, today: DateTime.now());
  await state.enterDemo(
    db,
    fromSettings: fromSettings,
    onLeave: () => DemoSession.clear(dir),
  );
}

/// Erster Start im Store-Build ohne Abo (FA-13.14): zwei große Knöpfe unten
/// in der Daumenzone, je 64 dp hoch, 16 dp Abstand. Kein Formular, keine
/// Frage davor.
class StartChoiceScreen extends StatefulWidget {
  const StartChoiceScreen({super.key});

  static const buttonHeight = 64.0;

  @override
  State<StartChoiceScreen> createState() => _StartChoiceScreenState();
}

class _StartChoiceScreenState extends State<StartChoiceScreen> {
  bool _busy = false;

  Future<void> _demo() async {
    setState(() => _busy = true);
    try {
      await startDemo(context);
    } on Object {
      if (mounted) showSnack(context, 'Die Demo ließ sich nicht öffnen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('JeNi bucht', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Belege fotografieren, Rechnungen schreiben, Steuertermine '
                  'im Blick – für Einzelunternehmen in Österreich und '
                  'Deutschland.',
                  style: theme.textTheme.bodyLarge,
                ),
                const Spacer(),
                Text(
                  key: const Key('start-trial-terms'),
                  '${LicensePolicy.trialDays} Tage kostenlos testen – mit '
                  'allen Pro-Funktionen. Danach gilt dein gewähltes Abo '
                  '(Preis aus dem Store). Jederzeit vorher im Store kündbar.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('start-subscribe'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, StartChoiceScreen.buttonHeight),
                  ),
                  onPressed: _busy ? null : () => openPaywall(context),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                    'Abo wählen – ${LicensePolicy.trialDays} Tage kostenlos',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('start-demo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, StartChoiceScreen.buttonHeight),
                  ),
                  onPressed: _busy ? null : _demo,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility_outlined),
                  label: const Text('Erst ansehen (Demo)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dauerhaftes Band oben in der Demo (FA-13.14), mindestens 48 dp hoch.
/// Tippen öffnet die Abo-Seite bzw. – bei Demo aus den Einstellungen –
/// das Blatt mit „Demo beenden“.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.navigator});

  /// Navigator der App; das Band liegt über ihm (MaterialApp.builder).
  final GlobalKey<NavigatorState> navigator;

  static const minHeight = 48.0;

  /// Dunkles Orange: Weiß darauf mit Kontrast über 4,5 : 1 (WCAG AA).
  static const color = Color(0xFF8A4F00);

  static const text =
      'DEMO – Abo wählen, um mit deinen eigenen Daten zu starten';
  static const textFromSettings = 'DEMO – Musterdaten. Tippen zum Beenden';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: color,
      child: InkWell(
        key: const Key('demo-banner'),
        onTap: () {
          final ctx = navigator.currentContext;
          if (ctx == null) return;
          if (state.demoFromSettings) {
            showDemoSheet(ctx);
          } else {
            openPaywall(ctx);
          }
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 4, 16, 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight - 8),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.demoFromSettings ? textFromSettings : text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ersatzinhalt für Bildschirme, die es in der Demo nicht gibt (Sicherung,
/// Wiederherstellung): Erklärung plus „Abo wählen“ unten.
class DemoUnavailable extends StatelessWidget {
  const DemoUnavailable({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'In der Demo wird nichts gesichert, exportiert oder '
        'wiederhergestellt. Mit einem Abo sicherst du hier deine eigenen '
        'Daten.',
        key: Key('demo-unavailable'),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: PrimaryActionBar.filled(
          key: const Key('demo-unavailable-subscribe'),
          label: 'Abo wählen',
          icon: Icons.workspace_premium_outlined,
          onPressed: () => openPaywall(context),
        ),
      ),
    ),
  );
}
