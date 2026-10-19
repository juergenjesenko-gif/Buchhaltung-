import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../services/licensing/license_policy.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'subscription_screen.dart';

/// Ein Hinweis zum Abo auf der Übersicht, höchstens einer zur Zeit
/// (Spezifikation FA-12.8): Herabstufung, Testende in 3 Tagen (L-10.3),
/// lange ohne Store-Bestätigung (L-22.5) oder Nur-Lese-Modus (L-22.6).
/// Tippen öffnet die Abo-Seite.
class LicenseNotice extends StatelessWidget {
  const LicenseNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final license = state.license;
    if (!license.enabled) return const SizedBox.shrink();
    final downgraded = license.downgradedFrom;
    final trialEnd = license.trialReminder;
    final basisFallback = trialEnd != null && license.proIncludedUntil != null;
    final message = switch (state.entitlement) {
      Entitlement.demo => null,
      _ when downgraded != null =>
        'Dein Abo ${downgraded == Tier.pro ? 'Pro' : 'Basis'} ist beendet. '
            'Jetzt: ${state.entitlement.label}. Deine Daten bleiben '
            'vollständig lesbar und exportierbar.',
      // Basis mit Pro inklusive (O-42): 3 Tage vorher, ein Tipp zu Pro.
      _ when basisFallback =>
        'Noch ${license.daysLeft(trialEnd)} '
            '${license.daysLeft(trialEnd) == 1 ? 'Tag' : 'Tage'} Pro '
            'inklusive – danach Basis. Jetzt auf Pro wechseln?',
      _ when trialEnd != null =>
        'Dein kostenloser Test endet am ${Fmt.date(trialEnd)}. Danach '
            'läuft Pro zum Store-Preis weiter, außer du kündigst vorher.',
      _ when license.needsOnlineCheck =>
        'Bitte öffne die App bald einmal mit Internet, damit der Store dein '
            'Abo bestätigt.',
      Entitlement.readOnly =>
        'Nur lesen: Ansehen, Exportieren und Sichern gehen weiter. Für neue '
            'Buchungen brauchst du ein Abo.',
      Entitlement.none => LicensePolicy.trialTeaser,
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NoticeBanner(
        key: const Key('license-notice'),
        icon: Icons.workspace_premium_outlined,
        color: downgraded != null ? AppTheme.warning : null,
        message: message,
        onTap: () async {
          await license.acknowledgeDowngrade();
          if (!context.mounted) return;
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        },
      ),
    );
  }
}
