import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../services/help/feedback_mail.dart';
import '../../services/help/support_mail.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/dictation_button.dart';
import '../../widgets/primary_action_bar.dart';

/// „Wunsch oder Idee senden“ (FA-11.6): kurzes Formular, gesendet wird aus
/// der Mail-App der Nutzerin. Die App selbst überträgt nichts.
/// Einhändig: Art als Chips (ein Tipp), Senden unten volle Breite 56 dp.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.launcher});

  /// Für Tests austauschbar.
  final SupportMailLauncher? launcher;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  var _kind = FeedbackKind.feature;
  var _withContext = true;
  var _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = AppScope.of(context);
    final l = widget.launcher ?? const SupportMailLauncher();
    setState(() => _busy = true);
    FeedbackContext? ctx;
    if (_withContext) {
      ctx = FeedbackContext(
        appVersion: await l.appVersion(),
        device: await l.deviceInfo(),
        country: state.profile?.country.code ?? '?',
        tier: state.license.enabled ? state.entitlement.label : 'Testversion',
      );
    }
    final mail = FeedbackMail(
      kind: _kind,
      title: _title.text,
      description: _description.text,
      context: ctx,
    );
    final opened = await l.openMail(mail.uri);
    if (!mounted) return;
    setState(() => _busy = false);
    if (opened) {
      Navigator.of(context).pop();
      return;
    }
    await Clipboard.setData(ClipboardData(text: mail.clipboardText));
    if (!mounted) return;
    showSnack(
      context,
      'Keine Mail-App gefunden. Text kopiert – sende ihn an $supportAddress.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wunsch oder Idee')),
      body: ReadableWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Was fehlt dir, was stört dich? Wir lesen jede Nachricht. '
                'Gesendet wird aus deiner Mail-App – du siehst vorher alles.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in FeedbackKind.values)
                    ChoiceChip(
                      key: Key('feedback-kind-${k.name}'),
                      label: Text(k.label),
                      selected: _kind == k,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('feedback-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Titel (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('feedback-description'),
                controller: _description,
                minLines: 4,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Beschreibung',
                  hintText: 'Tippen oder über das Mikrofon diktieren',
                  alignLabelWithHint: true,
                  suffixIcon: DictationButton(controller: _description),
                  suffixIconConstraints: const BoxConstraints(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Bitte beschreibe kurz deinen Wunsch.'
                    : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('feedback-context'),
                contentPadding: EdgeInsets.zero,
                title: const Text('App-Version und Gerät mitsenden'),
                subtitle: const Text(
                  'Nur App-Version, Betriebssystem, Gerätemodell, Länderprofil '
                  'und Abo – keine Geschäftsdaten, keine Belege.',
                ),
                value: _withContext,
                onChanged: (v) => setState(() => _withContext = v),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('feedback-send'),
          label: 'Per E-Mail senden',
          icon: Icons.send_outlined,
          busy: _busy,
          onPressed: _send,
        ),
      ),
    );
  }
}
