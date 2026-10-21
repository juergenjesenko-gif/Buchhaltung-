/// ZIP-Pakete mit Dokumenten für die Weitergabe über den Teilen-Dialog:
/// Belege und Rechnungen eines Zeitraums (FA-5.x „Belege & Rechnungen als
/// ZIP“) und alle Vertragsdokumente (L-23.11). Reines Dart: Dateinamen, CSV
/// und Zusammenstellen; das Lesen der Dateien und das PDF erledigt der Aufrufer.
/// Die Daten verlassen das Gerät nur über das Teilen-Blatt der Nutzerin.
library;

import 'dart:typed_data';

import '../../domain/contract.dart';
import '../../domain/invoice.dart';
import '../../domain/money.dart';
import '../../domain/receipt.dart';
import '../contracts/contract_csv.dart';
import '../reports/report_package.dart';
import 'csv.dart';

/// Datei eines Belegs (Seite oder Original) mit Inhalt.
class ReceiptFile {
  const ReceiptFile({
    required this.receipt,
    required this.extension,
    required this.bytes,
    this.page,
  });

  final Receipt receipt;

  /// Ohne Punkt, z. B. `jpg`, `pdf`.
  final String extension;
  final Uint8List bytes;

  /// Seitennummer ab 1; `null` = Originaldatei (PDF, XML).
  final int? page;
}

class DocumentPackage {
  DocumentPackage._();

  static const receiptsCsvName = 'Belege.csv';
  static const invoicesCsvName = 'Rechnungen.csv';

  /// Dateiname ohne Sonderzeichen: Umlaute bleiben lesbar, alles andere wird
  /// `-`; höchstens [maxLength] Zeichen. Leere Namen werden „unbenannt“.
  static String safe(String text, {int maxLength = 40}) {
    var s = text
        .trim()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('Ä', 'Ae')
        .replaceAll('Ö', 'Oe')
        .replaceAll('Ü', 'Ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.length > maxLength) {
      s = s.substring(0, maxLength).replaceAll(RegExp(r'-+$'), '');
    }
    return s.isEmpty ? 'unbenannt' : s;
  }

  static String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Betrag im Dateinamen: `12,50EUR`, negativ mit Minus.
  static String _amount(Money m) => '${csvAmount(m.cents)}EUR';

  /// Sprechender Name einer Belegdatei: `Belege/Datum_Partner_Betrag`, bei
  /// mehreren Seiten `_S2`, Original mit `_Original`.
  static String receiptFileName(ReceiptFile f) {
    final r = f.receipt;
    final partner = r.counterparty.trim().isNotEmpty
        ? r.counterparty
        : r.description;
    final suffix = f.page == null
        ? '_Original'
        : f.page! > 1
        ? '_S${f.page}'
        : '';
    return 'Belege/${_iso(r.date)}_${safe(partner)}_${_amount(r.gross)}'
        '$suffix.${f.extension.toLowerCase()}';
  }

  /// `Rechnungen/2026-03-04_RE-2026-001_Kunde_120,00EUR.pdf`.
  static String invoiceFileName(Invoice invoice, String customerName) =>
      'Rechnungen/${_iso(invoice.issueDate)}_${safe(invoice.number)}_'
      '${safe(customerName)}_${_amount(invoice.grossTotal)}.pdf';

  /// Hängt bei Namensgleichheit ` (2)`, ` (3)` … vor der Endung an.
  static String unique(String name, Set<String> used) {
    if (used.add(name)) return name;
    final dot = name.lastIndexOf('.');
    final base = dot < 0 ? name : name.substring(0, dot);
    final ext = dot < 0 ? '' : name.substring(dot);
    for (var i = 2; ; i++) {
      final candidate = '$base ($i)$ext';
      if (used.add(candidate)) return candidate;
    }
  }

  /// Übersicht der Belege; „Datei“ verweist auf den Namen im ZIP.
  static String receiptsCsv(
    List<Receipt> receipts,
    Map<int, List<String>> filesByReceipt,
  ) {
    final csv = CsvWriter()
      ..writeRow([
        'Beleg-ID',
        'Datum',
        'Art',
        'Partner',
        'Beschreibung',
        'Belegnummer',
        'Netto',
        'USt',
        'Brutto',
        'USt-Satz %',
        'Storniert',
        'Dateien',
      ]);
    for (final r in receipts) {
      csv.writeRow([
        r.id,
        _iso(r.date),
        r.direction == BookingDirection.income ? 'Einnahme' : 'Ausgabe',
        r.counterparty,
        r.description,
        r.documentNumber,
        csvAmount(r.net.cents),
        csvAmount(r.vat.cents),
        csvAmount(r.gross.cents),
        csvAmount(r.vatPermille * 10),
        r.isCancelled ? 'ja' : '',
        (filesByReceipt[r.id] ?? const []).join(' | '),
      ]);
    }
    return csv.build();
  }

  /// Übersicht der Rechnungen; „Datei“ verweist auf das PDF im ZIP.
  static String invoicesCsv(
    List<Invoice> invoices,
    Map<int, String> customerNames,
    Map<int, String> fileByInvoice,
  ) {
    final csv = CsvWriter()
      ..writeRow([
        'Rechnungsnummer',
        'Datum',
        'Kunde',
        'Status',
        'Netto',
        'USt',
        'Brutto',
        'Fällig',
        'Bezahlt am',
        'Storno zu',
        'Datei',
      ]);
    for (final i in invoices) {
      csv.writeRow([
        i.number,
        _iso(i.issueDate),
        customerNames[i.customerId] ?? '',
        i.status.label,
        csvAmount(i.netTotal.cents),
        csvAmount(i.vatTotal.cents),
        csvAmount(i.grossTotal.cents),
        i.dueDate == null ? '' : _iso(i.dueDate!),
        i.paidAt == null ? '' : _iso(i.paidAt!),
        i.cancelsNumber,
        fileByInvoice[i.id] ?? '',
      ]);
    }
    return csv.build();
  }

  /// Belege und Rechnungen eines Zeitraums als eine ZIP-Datei.
  /// [invoicePdfs]: Rechnungs-ID → PDF-Bytes (nur ausgestellte Rechnungen).
  static Uint8List receiptsAndInvoices({
    required List<Receipt> receipts,
    required List<ReceiptFile> receiptFiles,
    required List<Invoice> invoices,
    required Map<int, String> customerNames,
    required Map<int, Uint8List> invoicePdfs,
  }) {
    final used = <String>{};
    final files = <String, Uint8List>{};
    final filesByReceipt = <int, List<String>>{};
    for (final f in receiptFiles) {
      final name = unique(receiptFileName(f), used);
      files[name] = f.bytes;
      final id = f.receipt.id;
      if (id != null) (filesByReceipt[id] ??= []).add(name);
    }
    final fileByInvoice = <int, String>{};
    for (final i in invoices) {
      final pdf = invoicePdfs[i.id];
      if (pdf == null || i.id == null) continue;
      final name = unique(
        invoiceFileName(i, customerNames[i.customerId] ?? ''),
        used,
      );
      files[name] = pdf;
      fileByInvoice[i.id!] = name;
    }
    return ReportPackage.zip(
      pdfs: const {},
      files: files,
      csvs: {
        receiptsCsvName: receiptsCsv(receipts, filesByReceipt),
        invoicesCsvName: invoicesCsv(invoices, customerNames, fileByInvoice),
      },
    );
  }

  /// Ordner eines Vertrags im ZIP: `Vertraege/Bezeichnung_Partner`.
  static String contractFolder(Contract c) => [
    'Vertraege/${safe(c.title)}',
    if (c.partner.trim().isNotEmpty) safe(c.partner),
  ].join('_');

  /// Alle Verträge: Liste mit Fristen als CSV, dazu Seiten und Originale.
  /// [bytesByPath]: relativer Speicherpfad → Inhalt (fehlende werden
  /// übersprungen).
  static Uint8List contracts(
    List<Contract> contracts,
    Map<String, Uint8List> bytesByPath,
  ) {
    final used = <String>{};
    final files = <String, Uint8List>{};
    for (final c in contracts) {
      final folder = contractFolder(c);
      for (var i = 0; i < c.pages.length; i++) {
        final bytes = bytesByPath[c.pages[i]];
        if (bytes == null) continue;
        files[unique(
              '$folder/Seite_${i + 1}.${extensionOf(c.pages[i])}',
              used,
            )] =
            bytes;
      }
      final original = c.originalPath;
      final bytes = original == null ? null : bytesByPath[original];
      if (bytes != null) {
        files[unique('$folder/Original.${extensionOf(original!)}', used)] =
            bytes;
      }
    }
    return ReportPackage.zip(
      pdfs: const {},
      files: files,
      csvs: {ContractCsv.fileName: ContractCsv.build(contracts)},
    );
  }

  /// Endung eines Speicherpfads, Standard `jpg`.
  static String extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot < path.lastIndexOf('/')) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }
}
