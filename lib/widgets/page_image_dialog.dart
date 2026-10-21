import 'dart:io';

import 'package:flutter/material.dart';

/// Eine Seite (Foto/Scan) groß ansehen, mit Pinch-Zoom. Gemeinsam für Belege
/// und Verträge; „Schließen“ unten in der Daumenzone, 48 dp hoch.
Future<void> showPageImageDialog(
  BuildContext context, {
  required File file,
  required String caption,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(caption)),
        Flexible(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  ),
);
