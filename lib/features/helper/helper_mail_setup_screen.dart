import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../services/helper/helper_mail.dart';
import '../../services/helper/helper_mail_platform.dart';
import '../../services/mail/mail_autoconfig.dart';
import '../../services/mail/mail_credentials.dart';
import '../../services/mail/mail_server.dart';
import '../../services/mail/smtp_sender.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import 'mail_account_form.dart';

/// Mithelfer: „Mit deinem E-Mail-Konto senden“ (FA-17.9). Einmal
/// einrichten; danach gehen die Belege einmal am Tag und bei jedem Öffnen
/// der App von selbst. Das Konto gehört dem Mithelfer, Kennwort bzw.
/// App-Passwort bleibt nur auf diesem Handy (nie auf dem Hauptgerät).
class HelperMailSetupScreen extends StatefulWidget {
  const HelperMailSetupScreen({super.key});

  @override
  State<HelperMailSetupScreen> createState() => _HelperMailSetupScreenState();
}

class _HelperMailSetupScreenState extends State<HelperMailSetupScreen> {
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '465');
  final _user = TextEditingController();
  MailSecurity _security = MailSecurity.tls;
  bool _manual = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [_address, _password, _host, _port, _user]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await MailSendSettings.load(
      AppScope.read(context).repositories.helpers,
    );
    if (s == null || !mounted) return;
    setState(() {
      _address.text = s.address;
      _host.text = s.smtp.host;
      _port.text = '${s.smtp.port}';
      _user.text = s.smtp.user;
      _security = s.smtp.security;
    });
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    final address = _address.text.trim();
    if (!isMailAddress(address)) {
      setState(() => _error = 'Bitte deine E-Mail-Adresse eintragen.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Bitte Kennwort bzw. App-Passwort eintragen.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final MailServer? server = _manual && _host.text.trim().isNotEmpty
          ? MailServer(
              host: _host.text.trim(),
              port: int.tryParse(_port.text.trim()) ?? 0,
              security: _security,
              user: _user.text.trim().isEmpty ? address : _user.text.trim(),
            )
          : (await state.mailAutoconfig.lookup(address))?.smtp;
      if (server == null) {
        setState(() {
          _manual = true;
          if (_user.text.isEmpty) _user.text = address;
          _error =
              'Server nicht automatisch gefunden. Bitte die Angaben deines '
              'Anbieters eintragen (SMTP, meist Port 465 oder 587).';
        });
        return;
      }
      await SmtpSender(
        server,
        _password.text,
        connector: state.mailConnector,
      ).test();
      final repo = state.repositories.helpers;
      await state.mailCredentials.write(MailSlots.send, _password.text);
      await MailSendSettings(address: address, smtp: server).save(repo);
      if (!mounted) return;
      if (await repo.setting(MailSettingKeys.permissionsExplained) == null) {
        if (!mounted) return;
        if (await explainMailPermissions(context, helper: true)) {
          await LocalHelperNotifier.instance.requestPermission();
        }
        await repo.setSetting(MailSettingKeys.permissionsExplained, '1');
      }
      await state.configureMailBackground();
      await state.runMailSync();
      if (!mounted) return;
      showSnack(context, 'Eingerichtet. Belege gehen jetzt von selbst.');
      Navigator.of(context).pop(true);
    } on MailException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (!e.authentication) _manual = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = MailAutoconfig.providerOf(_address.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Mit deinem E-Mail-Konto senden')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (_error != null) ...[
            NoticeBanner(
              key: const Key('smtp-error'),
              icon: Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              message: _error!,
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Einmal einrichten: dann sendet dieses Handy deine Belege einmal '
            'am Tag und bei jedem Öffnen der App – verschlüsselt, aus deinem '
            'eigenen Postfach. Dein Kennwort bleibt nur auf diesem Handy.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('smtp-address'),
            controller: _address,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Deine E-Mail-Adresse',
            ),
          ),
          const SizedBox(height: 12),
          PasswordField(
            key: const Key('smtp-password'),
            controller: _password,
            label: provider == MailProvider.other
                ? 'Kennwort oder App-Passwort'
                : 'App-Passwort',
          ),
          const SizedBox(height: 12),
          AppPasswordGuide(provider: provider),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('smtp-manual'),
            contentPadding: EdgeInsets.zero,
            minTileHeight: 48,
            title: const Text('Server selbst eintragen'),
            trailing: Icon(_manual ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _manual = !_manual),
          ),
          if (_manual)
            MailServerFields(
              keyPrefix: 'smtp',
              title: 'Ausgangsserver (SMTP)',
              host: _host,
              port: _port,
              user: _user,
              security: _security,
              onSecurity: (s) => setState(() {
                _security = s;
                _port.text = s == MailSecurity.tls ? '465' : '587';
              }),
            ),
        ],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('smtp-save'),
          label: 'Prüfen und speichern',
          icon: Icons.check,
          busy: _busy,
          onPressed: _save,
        ),
      ),
    );
  }
}
