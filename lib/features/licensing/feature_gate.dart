import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../services/licensing/license_policy.dart';
import 'subscription_screen.dart';

/// Einzige Stelle, an der die Oberfläche eine gesperrte Funktion behandelt
/// (L-22.1): erlaubt → `true`; sonst Abo-Seite mit Begründung, danach erneut
/// prüfen. Ansehen, Export und Sicherung rufen das nie auf (L-22.6).
Future<bool> ensureFeature(BuildContext context, Feature feature) async {
  final state = AppScope.read(context);
  if (state.allows(feature)) return true;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SubscriptionScreen(reason: featureReason(feature)),
    ),
  );
  return state.allows(feature);
}

String featureReason(Feature feature) => switch (feature) {
  Feature.newBookings =>
    'Neue Buchungen brauchen ein Abo. Deine bisherigen Daten kannst du '
        'jederzeit ansehen, exportieren und sichern.',
  Feature.receiptRecognition =>
    'Die Belegerkennung gibt es mit Pro. Tippen geht in jedem Abo.',
};
