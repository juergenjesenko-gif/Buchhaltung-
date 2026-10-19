import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../app_state.dart';
import '../../services/e_invoice/e_invoice_output.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/share_service.dart';
import '../demo/demo_sheet.dart';
import '../licensing/feature_gate.dart';

/// Seiten eines PDF als Bilder; austauschbar für Widget-Tests.
typedef PdfRasterizer = Stream<ImageProvider> Function(Uint8List bytes);

/// Systemdruckdialog; austauschbar für Widget-Tests.
typedef PdfPrinter = Future<void> Function(Uint8List bytes, String name);

/// Druckt über den Systemdialog (Android Print Framework, iOS
/// UIPrintInteractionController). Dort geht auch „Als PDF speichern“.
Future<void> printPdfWithSystemDialog(Uint8List bytes, String name) async {
  await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
}

/// Rendert jede Seite mit 144 dpi (doppelte Bildschirmdichte bei 100 %);
/// genug für Pinch-Zoom auf Lesegröße, ohne den Speicher zu sprengen.
Stream<ImageProvider> rasterPdfPages(Uint8List bytes) async* {
  await for (final page in Printing.raster(bytes, dpi: 144)) {
    yield MemoryImage(await page.toPng());
  }
}

/// Farbe des Papiers im Betrachter – unabhängig vom Farbschema.
const pdfPaperColor = Colors.white;

/// PDF ansehen, bevor es gesendet oder gedruckt wird (FA-5.48).
///
/// Liefert `true`, wenn gesendet wurde (Angebot gilt dann als gesendet).
Future<bool> openPdfViewer(
  BuildContext context, {
  required String title,
  required String fileName,
  required Uint8List bytes,
  Feature? sendFeature,
  String? subject,
  String? text,
  String? notice,
  XmlAttachment? xml,
}) async {
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PdfViewerScreen(
        title: title,
        fileName: fileName,
        bytes: bytes,
        sendFeature: sendFeature,
        subject: subject,
        text: text,
        notice: notice,
        xml: xml,
      ),
    ),
  );
  return sent ?? false;
}

/// Eigener Betrachter mit `printing` (Seiten rendern, Systemdruck):
/// Seiten wischen, Pinch-Zoom, Seitenanzeige; unten in der Daumenzone
/// „Senden“, „Drucken“, „Schließen“ mit 56 dp Höhe.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.bytes,
    this.sendFeature,
    this.subject,
    this.text,
    this.notice,
    this.xml,
    this.rasterizer = rasterPdfPages,
    this.printer = printPdfWithSystemDialog,
  });

  final String title;
  final String fileName;
  final Uint8List bytes;

  /// Tarifschnitt für „Senden“ (FA-13.11); `null` = Teilen wie ein Export
  /// (Berichte, Beleganhänge; L-22.6).
  final Feature? sendFeature;
  final String? subject;
  final String? text;

  /// Hinweiszeile über der Leiste, z. B. „Mit E-Rechnung (ZUGFeRD)“.
  final String? notice;

  /// Gesetzt: „XML senden“ schickt diese Datei statt des PDF (Behörden).
  final XmlAttachment? xml;
  final PdfRasterizer rasterizer;
  final PdfPrinter printer;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _pages = <ImageProvider>[];
  final _controller = PageController();
  var _index = 0;
  var _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget
        .rasterizer(widget.bytes)
        .listen(
          (page) {
            if (mounted) setState(() => _pages.add(page));
          },
          onError: (Object e) {
            if (mounted) setState(() => _error = e);
          },
          onDone: () {
            if (mounted) setState(() => _done = true);
          },
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _demo => AppScope.read(context).isDemo;

  Future<void> _send() async {
    // Demo (FA-13.14): nichts verlässt das Gerät, Hinweisblatt statt Teilen.
    if (_demo) {
      await showDemoSheet(context, feature: Feature.dataExport);
      return;
    }
    final xml = widget.xml;
    if (xml != null) {
      if (!await ensureFeature(context, Feature.eInvoiceIssue)) return;
      await ShareService.shareXml(
        fileName: xml.fileName,
        content: xml.content,
        subject: widget.subject ?? widget.title,
      );
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final feature = widget.sendFeature;
    if (feature == null) {
      await ShareService.sharePdf(
        fileName: widget.fileName,
        bytes: widget.bytes,
        subject: widget.subject,
      );
    } else {
      await sendPdfGated(
        context,
        feature,
        fileName: widget.fileName,
        bytes: widget.bytes,
        subject: widget.subject ?? widget.title,
        text: widget.text ?? '',
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Drucken ist in jedem Anspruch frei (L-10.4), nur nicht in der Demo.
  Future<void> _print() async {
    if (_demo) {
      await showDemoSheet(context, feature: Feature.dataExport);
      return;
    }
    await widget.printer(widget.bytes, widget.fileName);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final demo = state.isDemo;
    final feature = widget.sendFeature;
    final sendLabel = widget.xml != null
        ? 'XML senden'
        : feature == null
        ? 'Senden'
        : proLabel(context, feature, 'Senden');
    final theme = Theme.of(context);
    final total = _pages.length;
    final indicator = total == 0
        ? ''
        : _done
        ? 'Seite ${_index + 1} von $total'
        : 'Seite ${_index + 1} von $total …';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('PDF kann nicht angezeigt werden: $_error'),
                    ),
                  )
                : total == 0
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    key: const Key('pdf-pages'),
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => InteractiveViewer(
                      key: Key('pdf-page-$i'),
                      maxScale: 5,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          // Papier ist immer weiß (auch im dunklen Modus):
                          // das Rasterbild ist dort transparent, wo die
                          // Seite nichts zeichnet. Keine Farbfilter.
                          child: Material(
                            key: Key('pdf-paper-$i'),
                            color: pdfPaperColor,
                            surfaceTintColor: Colors.transparent,
                            elevation: 2,
                            child: Image(image: _pages[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (indicator.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                indicator,
                key: const Key('pdf-page-indicator'),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
      bottomNavigationBar: Material(
        color: theme.colorScheme.surfaceContainer,
        elevation: 3,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.notice != null && !demo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.notice!,
                      key: const Key('pdf-notice'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (demo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Demo: Senden und Drucken gibt es mit Abo.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _BarButton(
                        key: const Key('pdf-close'),
                        label: 'Schließen',
                        icon: Icons.close,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BarButton(
                        key: const Key('pdf-print'),
                        label: 'Drucken',
                        icon: Icons.print_outlined,
                        dimmed: demo,
                        onPressed: _print,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BarButton(
                        key: const Key('pdf-send'),
                        label: sendLabel,
                        icon: Icons.send_outlined,
                        filled: true,
                        dimmed: demo,
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Knopf der Leiste: 56 dp hoch, Beschriftung unter dem Symbol, damit drei
/// Knöpfe nebeneinander auch bei großer Schrift lesbar bleiben. „Gedimmt“
/// in der Demo, bleibt aber tippbar und erklärt sich mit dem Hinweisblatt.
class _BarButton extends StatelessWidget {
  const _BarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.dimmed = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
    );
    final button = filled
        ? FilledButton(style: style, onPressed: onPressed, child: child)
        : OutlinedButton(style: style, onPressed: onPressed, child: child);
    return Opacity(opacity: dimmed ? 0.5 : 1, child: button);
  }
}
