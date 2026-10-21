import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/company_profile.dart';
import '../../domain/customer.dart';
import '../../domain/invoice.dart';
import '../../services/e_invoice/e_invoice_output.dart';
import '../../services/e_invoice/e_invoice_writer.dart';
import '../../services/invoice_logo.dart';
import '../../services/invoice_pdf.dart';
import '../../services/invoice_seller.dart';
import '../../services/logo_store.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/invoice_texts.dart';
import '../../widgets/common.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';

/// Rechnungs-PDF wie beim Senden; gemeinsam für Betrachter und ZIP-Export.
/// Gestellte Rechnungen mit den eingefrorenen Absenderangaben (GR-8).
Future<(Uint8List, EInvoiceOutput)> buildInvoicePdf(
  AppState state,
  Invoice invoice,
  Customer customer,
  CompanyProfile profile,
) async {
  final logo = await LogoStore.readBytes(
    InvoiceLogo.pathFor(
      invoice,
      profile,
      logoAllowed: state.allows(Feature.invoiceLogo),
    ),
  );
  final seller = InvoiceSeller.profileFor(invoice, profile);
  final eInvoice = EInvoiceOutput.prepare(
    input: EInvoiceInput(invoice: invoice, seller: seller, buyer: customer),
    format: customer.eInvoiceFormat,
    allowed: state.allows(Feature.eInvoiceIssue),
    demo: state.isDemo,
  );
  final bytes = await InvoicePdf(
    invoice: invoice,
    customer: customer,
    profile: seller,
    logo: logo,
    facturX: eInvoice.facturX,
  ).build();
  return (bytes, eInvoice);
}

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
    final (bytes, eInvoice) = await buildInvoicePdf(
      state,
      invoice,
      customer,
      profile,
    );
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
      notice: eInvoice.notice,
      xml: eInvoice.xml,
    );
  } on Exception catch (error) {
    if (context.mounted) {
      showSnack(context, 'PDF konnte nicht erstellt werden: $error');
    }
  }
}
