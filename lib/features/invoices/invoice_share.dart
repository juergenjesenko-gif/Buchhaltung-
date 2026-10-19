import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/invoice.dart';
import '../../services/invoice_logo.dart';
import '../../services/invoice_pdf.dart';
import '../../services/invoice_seller.dart';
import '../../services/logo_store.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/invoice_texts.dart';
import '../../widgets/common.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';

/// Erzeugt das Rechnungs-PDF und öffnet den Betrachter (FA-5.10, FA-5.48).
/// Gemeinsam für Rechnungsliste und Rechnungsformular („PDF senden“ direkt
/// nach dem Ausstellen).
Future<void> shareInvoicePdf(BuildContext context, Invoice invoice) async {
  final state = AppScope.read(context);
  final profile = state.profile;
  final customer = await state.repositories.customers.byId(invoice.customerId);
  if (!context.mounted) return;
  if (profile == null || customer == null) {
    showSnack(context, 'Kundendaten fehlen – PDF kann nicht erzeugt werden.');
    return;
  }
  try {
    final logo = await LogoStore.readBytes(
      InvoiceLogo.pathFor(
        invoice,
        profile,
        logoAllowed: state.allows(Feature.invoiceLogo),
      ),
    );
    final bytes = await InvoicePdf(
      invoice: invoice,
      customer: customer,
      // Gestellte Rechnungen mit den eingefrorenen Absenderangaben (GR-8).
      profile: InvoiceSeller.profileFor(invoice, profile),
      logo: logo,
    ).build();
    final safeNumber = invoice.number.replaceAll(
      RegExp(r'[^A-Za-z0-9\-_]'),
      '-',
    );
    if (!context.mounted) return;
    // Erst ansehen, dann senden oder drucken (FA-5.48).
    await openPdfViewer(
      context,
      title: invoice.isCancellation
          ? InvoiceTexts.cancellationTitle(invoice.number)
          : 'Rechnung ${invoice.number}',
      sendFeature: Feature.pdfSending,
      fileName: invoice.isCancellation
          ? 'Stornorechnung_$safeNumber.pdf'
          : 'Rechnung_$safeNumber.pdf',
      bytes: bytes,
      subject: invoice.isCancellation
          ? InvoiceTexts.cancellationTitle(invoice.number)
          : 'Rechnung ${invoice.number}',
      text: invoice.isCancellation
          ? InvoiceTexts.shareCancellation(
              invoice.number,
              invoice.cancelsNumber,
            )
          : InvoiceTexts.shareInvoice(invoice.number),
    );
  } on Exception catch (error) {
    if (context.mounted) {
      showSnack(context, 'PDF konnte nicht erstellt werden: $error');
    }
  }
}
