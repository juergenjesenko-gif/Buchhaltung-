import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/share_service.dart';
import '../demo/demo_sheet.dart';
import 'subscription_screen.dart';

/// Einzige Stelle, an der die Oberfläche eine gesperrte Funktion behandelt
/// (L-22.1): erlaubt → `true`; sonst Abo-Seite mit Begründung, danach erneut
/// prüfen. Ansehen, Export und Sicherung rufen das nie auf (L-22.6).
Future<bool> ensureFeature(BuildContext context, Feature feature) async {
  final state = AppScope.read(context);
  if (state.allows(feature)) return true;
  // Demo (FA-13.14): statt der Abo-Seite das Hinweisblatt „In der Demo wird
  // nichts gespeichert“ mit „Abo wählen“.
  if (state.isDemo) {
    await showDemoSheet(context, feature: feature);
    return false;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SubscriptionScreen(reason: featureReason(feature)),
    ),
  );
  return state.allows(feature);
}

/// Ändern bestehender Daten (Belege, Rechnungen, Stammdaten). Ohne Abo
/// erlaubt (L-22.6: Ändern bleibt), nur in der Demo nicht (FA-13.14).
Future<bool> ensureWritable(BuildContext context) async {
  final state = AppScope.read(context);
  if (!state.isDemo) return true;
  await showDemoSheet(context);
  return false;
}

String featureReason(Feature feature) => switch (feature) {
  Feature.dataExport =>
    'In der Demo wird nichts exportiert, geteilt oder gesichert.',
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
  Feature.helperDevices =>
    'Mithelfer-Geräte koppeln gibt es mit Pro. Belege, die schon gesendet '
        'wurden, nimmt der Eingang in jedem Abo an.',
  Feature.contractSummary =>
    'Texterkennung und Kurzübersicht für Verträge gibt es mit Pro. Ablegen '
        'und Fristen gehen in jedem Abo.',
  Feature.annualReports =>
    'Saldenliste und vorläufigen Jahresabschluss gibt es mit Pro. Das '
        'Anlagenverzeichnis und den Export bekommst du in jedem Abo.',
  Feature.levyReserve =>
    'Abgaben & Rücklagen gibt es mit Pro. Deine Buchungen für Steuern und '
        'Sozialversicherung bleiben in jedem Abo ganz normale Buchungen.',
  Feature.assetManagement =>
    'Anlagen anlegen, ändern und ausscheiden gibt es mit Pro. Erfasste '
        'Anlagen, ihre AfA und das Anlagenverzeichnis bleiben in jedem Abo.',
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
  // Demo: das Hinweisblatt kam schon, nichts verlässt das Gerät (FA-13.14).
  if (!context.mounted || AppScope.read(context).isDemo) return;
  await ShareService.sharePdf(fileName: fileName, bytes: bytes);
}
