import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/legal_texts.dart';
import '../../services/help/support_mail.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../help/help_screen.dart';

/// Menü „Rechtliches“ (L-22.18, Store-Pflicht): Impressum,
/// Datenschutzerklärung, Nutzungsbedingungen, Hinweis „keine
/// Steuerberatung“, Support und Open-Source-Lizenzen. Alles offline lesbar.
/// Jede Zeile ist eine volle ListTile (≥ 56 dp), untereinander mit dem
/// Daumen erreichbar (DESIGN_SPEC 5a).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.launcher});

  /// Für Tests austauschbar.
  final SupportMailLauncher? launcher;

  Future<void> _mail(BuildContext context) async {
    final l = launcher ?? const SupportMailLauncher();
    final version = await l.appVersion();
    final opened = await l.openMail(
      supportMailUri(supportSubject(version, '')),
    );
    if (opened || !context.mounted) return;
    showSnack(context, 'Keine Mail-App gefunden. Schreib an $supportAddress.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechtliches')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: [
            for (final doc in LegalDocument.values)
              ListTile(
                key: Key('legal-${doc.name}'),
                leading: const Icon(Icons.article_outlined),
                title: Text(doc.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LegalDocumentScreen(document: doc),
                  ),
                ),
              ),
            ListTile(
              key: const Key('legal-disclaimer'),
              leading: const Icon(Icons.info_outline),
              title: Text(LegalText.disclaimer.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(LegalText.disclaimer.title),
                  content: Text(LegalText.disclaimer.summary),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              key: const Key('legal-support'),
              leading: const Icon(Icons.mail_outline),
              title: const Text('Support'),
              subtitle: const Text(supportAddress),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _mail(context),
            ),
            ListTile(
              key: const Key('legal-licenses'),
              leading: const Icon(Icons.code),
              title: const Text('Open-Source-Lizenzen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'JeNi bucht',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Rechtstext aus `docs/legal/`, mit dem Markdown-Darsteller der Hilfe.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document, this.bundle});

  final LegalDocument document;

  /// Für Tests austauschbar.
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: FutureBuilder<String>(
        future: (bundle ?? rootBundle).loadString(document.asset),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ReadableWidth(
            child: SelectionArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (!LegalDocument.reviewed) ...[
                    const NoticeBanner(
                      key: Key('legal-draft'),
                      icon: Icons.edit_note,
                      message:
                          'Entwurf – noch nicht anwaltlich geprüft. Gilt für '
                          'diesen Testbuild.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...markdownBlocks(
                    context,
                    LegalDocument.body(snapshot.data!),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
