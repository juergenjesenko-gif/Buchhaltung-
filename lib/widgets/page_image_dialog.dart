import 'dart:io';

import 'package:flutter/material.dart';

/// Seiten (Fotos/Scans) groß ansehen und seitlich durchblättern, je Seite
/// mit Pinch-Zoom. Gemeinsam für Belege und Verträge (Rückmeldung
/// 2026-10-21: „durchblättern statt jede Seite einzeln öffnen“).
/// „Schließen“ unten in der Daumenzone, 48 dp hoch. `null` in [files] =
/// Seite nicht gefunden.
Future<void> showPageImageDialog(
  BuildContext context, {
  required List<File?> files,
  int initialIndex = 0,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _PageViewerDialog(files: files, initialIndex: initialIndex),
);

class _PageViewerDialog extends StatefulWidget {
  const _PageViewerDialog({required this.files, required this.initialIndex});

  final List<File?> files;
  final int initialIndex;

  @override
  State<_PageViewerDialog> createState() => _PageViewerDialogState();
}

class _PageViewerDialogState extends State<_PageViewerDialog> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) => _controller.animateToPage(
    _index + delta,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.files.length;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Seite ${_index + 1} von $count',
                key: const Key('page-viewer-caption'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('page-viewer'),
                controller: _controller,
                itemCount: count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final file = widget.files[i];
                  return file == null
                      ? Center(child: Text('Seite ${i + 1} nicht gefunden.'))
                      : InteractiveViewer(
                          maxScale: 5,
                          child: Image.file(file, fit: BoxFit.contain),
                        );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Vorherige Seite',
                    onPressed: _index > 0 ? () => _go(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Schließen'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nächste Seite',
                    onPressed: _index < count - 1 ? () => _go(1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
