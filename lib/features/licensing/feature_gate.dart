import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/share_service.dart';
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
  Feature.dataImport =>
    'Der Import aus Amazon, PayPal, Shopify, Stripe und aus E-Rechnungen '
        'gibt es mit Pro. Die Datei bleibt am Beleg gespeichert.',
  Feature.taxOfficeSubmission =>
    'Die direkte Übermittlung ans Finanzamt gibt es mit Pro.',
  Feature.pdfSending =>
    'PDF mit einem Tipp senden gibt es mit Pro. Ohne Pro kannst du das PDF '
        'speichern oder drucken und selbst weitergeben.',
  Feature.dunningSending =>
    'Mahnungen mit einem Tipp senden gibt es mit Pro. Ohne Pro kannst du '
        'das PDF speichern oder drucken und selbst weitergeben.',
  Feature.invoiceLogo =>
    'Dein Logo auf Rechnungen und Angeboten gibt es mit Pro.',
  Feature.exchangeRateFetch =>
    'Kurs abrufen gibt es mit Pro. Den Kurs eintippen geht in jedem Abo.',
  Feature.contractSummary =>
    'Texterkennung und Kurzübersicht für Verträge gibt es mit Pro. Ablegen '
        'und Fristen gehen in jedem Abo.',
  Feature.annualReports =>
    'Saldenliste und vorläufigen Jahresabschluss gibt es mit Pro. Das '
        'Anlagenverzeichnis und den Export bekommst du in jedem Abo.',
};

/// Beschriftung mit Pro-Hinweis für Knöpfe, die ohne Pro zur Abo-Seite
/// führen (FA-13.9).
String proLabel(BuildContext context, Feature feature, String label) =>
    AppScope.of(context).allows(feature) ? label : '$label (Pro)';

/// PDF senden mit Tarifschnitt (FA-13.11): mit Pro direkt mit Betreff und
/// Text; ohne Pro erst die Abo-Seite, danach – damit die Arbeit nicht
/// verloren geht und das Dokument die Kundin immer erreichen kann (L-10.4) –
/// der Systemdialog ohne Mailtext zum Speichern oder Drucken.
Future<void> sendPdfGated(
  BuildContext context,
  Feature feature, {
  required String fileName,
  required Uint8List bytes,
  required String subject,
  required String text,
}) async {
  if (await ensureFeature(context, feature)) {
    await ShareService.sharePdf(
      fileName: fileName,
      bytes: bytes,
      subject: subject,
      text: text,
    );
    return;
  }
  await ShareService.sharePdf(fileName: fileName, bytes: bytes);
}
