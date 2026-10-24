import 'package:flutter/material.dart';

import '../services/launcher/open_url.dart';
import 'common.dart';

/// Öffnet eine amtliche Quelle im Browser; ohne Browser ein Hinweis mit der
/// Adresse zum Abschreiben.
Future<void> openSource(BuildContext context, String url) async {
  final ok = await openInBrowser(Uri.parse(url));
  if (ok || !context.mounted) return;
  showSnack(context, 'Kein Browser gefunden: $url');
}

/// Kleiner Link „Quelle: …“ zur amtlichen Fundstelle (Google-Play-Vorgabe
/// „Missing Source Link for Government Information“). Mindestens 48 dp hoch,
/// damit er mit dem Daumen sicher trifft (DESIGN_SPEC 5a).
class SourceLinkButton extends StatelessWidget {
  const SourceLinkButton({super.key, required this.url, required this.label});

  final String url;

  /// Fundstelle, z. B. „§ 11 UStG“.
  final String label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
    onPressed: () => openSource(context, url),
    icon: const Icon(Icons.open_in_new, size: 18),
    label: Text('Quelle: $label'),
  );
}
