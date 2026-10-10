import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/formatting.dart';
import '../services/vat_id/vat_id_format.dart';
import '../services/vat_id/vies_client.dart';
import '../theme.dart';

/// Klartext zu einem Prüfergebnis. „Nicht erreichbar" ist nie „ungültig".
String vatCheckMessage(VatCheck check) {
  final when = Fmt.date(check.checkedAt);
  switch (check.result) {
    case VatCheckResult.valid:
      final name = check.name.isEmpty ? '' : ' (${check.name})';
      final id = check.requestIdentifier.isEmpty
          ? ''
          : ', Abfragenummer ${check.requestIdentifier}';
      return 'Gültig laut EU-Prüfsystem VIES$name – geprüft am $when$id.';
    case VatCheckResult.invalid:
      return 'Laut EU-Prüfsystem VIES am $when ungültig. Bitte die Nummer mit '
          'dem Kunden klären. Für den Nachweis gegenüber dem Finanzamt dient '
          'die qualifizierte Abfrage (FinanzOnline bzw. Bundeszentralamt für '
          'Steuern).';
    case VatCheckResult.unavailable:
      return 'Am $when nicht prüfbar – das Prüfsystem des Landes war nicht '
          'erreichbar. Das sagt nichts über die Gültigkeit; die App versucht es '
          'später erneut.';
    case VatCheckResult.formatError:
      return VatIdFormat.check(check.vatId) ?? 'Ungültiges Format.';
  }
}

/// Zeigt den letzten Prüfstand einer UID und erlaubt eine Prüfung auf Tippen.
class VatCheckStatus extends StatefulWidget {
  const VatCheckStatus({
    super.key,
    required this.vatId,
    required this.subject,
    this.subjectId,
  });

  final String vatId;
  final String subject;
  final int? subjectId;

  @override
  State<VatCheckStatus> createState() => _VatCheckStatusState();
}

class _VatCheckStatusState extends State<VatCheckStatus> {
  VatCheck? _check;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(VatCheckStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vatId != widget.vatId) _load();
  }

  Future<void> _load() async {
    final normalized = VatIdFormat.normalize(widget.vatId);
    if (normalized.isEmpty) return;
    final check = await AppScope.read(
      context,
    ).repositories.vatChecks.latest(normalized);
    if (mounted) setState(() => _check = check);
  }

  Future<void> _checkNow() async {
    final state = AppScope.read(context);
    final profile = state.profile;
    if (profile == null) return;
    setState(() => _busy = true);
    final check = await state.vatCheckService.check(
      widget.vatId,
      profile: profile,
      subject: widget.subject,
      subjectId: widget.subjectId,
    );
    if (mounted) {
      setState(() {
        _check = check;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vatId.trim().isEmpty ||
        VatIdFormat.check(widget.vatId) != null) {
      return const SizedBox.shrink();
    }
    final check = _check;
    final color = switch (check?.result) {
      VatCheckResult.valid => AppTheme.income,
      VatCheckResult.invalid => AppTheme.expense,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              check == null
                  ? 'Noch nicht über VIES geprüft. Die Prüfung sendet die '
                        'Nummer an die EU-Kommission.'
                  : vatCheckMessage(check),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _checkNow,
            child: Text(_busy ? 'Prüfe …' : 'Jetzt prüfen'),
          ),
        ],
      ),
    );
  }
}
