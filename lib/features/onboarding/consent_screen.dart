import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/legal_texts.dart';
import '../../l10n/l10n.dart';
import '../../widgets/adaptive.dart';
import '../settings/legal_screen.dart';

/// Bestätigungen bei der ersten Einrichtung und nach Textänderungen
/// (Lastenheft L-17.1 bis L-17.4, FA-1.10).
///
/// Prüfinstanz Rechtsanwalt 2026-10-19: Nur „Keine Steuerberatung“ braucht
/// ein eigenes, nicht vorausgewähltes Häkchen (L-17.2). Die
/// Nutzungsbedingungen werden mit dem beschrifteten Knopf „Akzeptieren und
/// weiter“ angenommen (Hinweis, zumutbare Kenntnisnahme über die Links,
/// Einverständnis: § 305 Abs 2 BGB, § 864a ABGB); die Datenschutzerklärung
/// ist Information nach Art 13 DSGVO, keine Einwilligung. Zwei Tipps statt
/// drei. Reale Prüfung: P-R58.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.texts});

  final List<LegalText> texts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.consentTitle),
        automaticallyImplyLeading: false,
      ),
      body: ConsentPanel(texts: texts, onAccepted: () {}),
    );
  }
}

/// Inhalt der Bestätigung, auch Schritt 1 der Ersteinrichtung.
class ConsentPanel extends StatefulWidget {
  const ConsentPanel({
    super.key,
    required this.texts,
    required this.onAccepted,
    this.header,
  });

  final List<LegalText> texts;
  final VoidCallback onAccepted;

  /// Zeile über dem Inhalt, z. B. „Schritt 1 von 5“.
  final Widget? header;

  @override
  State<ConsentPanel> createState() => _ConsentPanelState();
}

class _ConsentPanelState extends State<ConsentPanel> {
  bool _disclaimerChecked = false;
  bool _saving = false;

  bool get _needsDisclaimer =>
      widget.texts.any((t) => t.kind == LegalText.disclaimer.kind);

  bool get _complete => !_needsDisclaimer || _disclaimerChecked;

  Future<void> _accept() async {
    setState(() => _saving = true);
    await AppScope.read(context).acceptConsents();
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onAccepted();
  }

  void _open(LegalDocument doc) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(document: doc)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final terms = widget.texts.where((t) => t.kind != 'disclaimer');
    return Column(
      children: [
        Expanded(
          child: ReadableWidth(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.header != null) widget.header!,
                  for (final text in widget.texts)
                    if (text.kind == LegalText.disclaimer.kind) ...[
                      Text(text.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(text.summary),
                      CheckboxListTile(
                        key: const Key('consent-disclaimer'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _disclaimerChecked,
                        onChanged: (value) =>
                            setState(() => _disclaimerChecked = value == true),
                        title: Text(text.confirmation),
                      ),
                      const SizedBox(height: 16),
                    ],
                  for (final text in terms) ...[
                    Text(text.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(text.summary),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final doc in const [
                          LegalDocument.terms,
                          LegalDocument.privacy,
                        ])
                          TextButton.icon(
                            key: Key('consent-open-${doc.name}'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => _open(doc),
                            icon: const Icon(Icons.description_outlined),
                            label: Text(doc.title),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.consentWith(l10n.consentAccept, text.confirmation),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ReadableWidth(
              child: FilledButton.icon(
                key: const Key('consent-accept'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _complete && !_saving ? _accept : null,
                icon: const Icon(Icons.check),
                label: Text(
                  terms.isEmpty ? l10n.consentConfirm : l10n.consentAccept,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
