import 'package:flutter/material.dart';

/// Hinweisstreifen über der Speicherleiste (L-27.7): „Rechnung von ‹Domain›
/// laden?“. Die Domain steht groß, damit eine fremde Adresse auffällt.
/// Nichts wird geladen, bevor „Laden“ getippt ist. Alle Knöpfe ≥ 48 dp, im
/// Daumenbereich unten, mit Abstand zur Speicherleiste (DESIGN_SPEC 5a).
class LinkInvoiceStrip extends StatelessWidget {
  const LinkInvoiceStrip({
    super.key,
    required this.domain,
    required this.onLoad,
    required this.onBrowser,
    required this.onDismiss,
    this.loading = false,
    this.redirected = false,
  });

  final String domain;
  final VoidCallback onLoad;
  final VoidCallback onBrowser;
  final VoidCallback onDismiss;
  final bool loading;

  /// Nach einer Weiterleitung auf eine andere Domain erneut gezeigt.
  final bool redirected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      redirected
                          ? 'Weiterleitung – Rechnung jetzt von'
                          : 'QR-Code: Rechnung laden von',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hinweis schließen',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: loading ? null : onDismiss,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                domain,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: loading ? null : onBrowser,
                      child: const Text('Im Browser öffnen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: loading ? null : onLoad,
                      child: loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Laden'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
