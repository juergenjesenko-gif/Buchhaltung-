import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../services/helper/helper_mail.dart';
import '../../services/mail/mail_autoconfig.dart';
import '../../services/mail/mail_credentials.dart';
import '../../services/mail/mail_server.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import 'mail_account_form.dart';

/// Hauptgerät: Empfang der Mithelfer-Belege per E-Mail (FA-17.9).
///
/// Standard ist die Geschäfts-E-Mail aus den Stammdaten; das Häkchen „Andere
/// E-Mail-Adresse für den Empfang von Belegen“ öffnet ein eigenes Feld (wie
/// eine abweichende Rechnungsadresse). Der Zugang zum Postfach ist **nur
/// lesend**; das Kennwort bleibt im sicheren Speicher dieses Geräts.
class MailReceiveScreen extends StatefulWidget {
  const MailReceiveScreen({super.key});

  @override
  State<MailReceiveScreen> createState() => _MailReceiveScreenState();
}

class _MailReceiveScreenState extends State<MailReceiveScreen> {
  final _other = TextEditingController();
  final _password = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '993');
  final _user = TextEditingController();
  MailSecurity _security = MailSecurity.tls;
  bool _useOther = false;
  bool _manual = false;
  bool _busy = false;
  bool _connected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [_other, _password, _host, _port, _user]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    final s = await MailReceiveSettings.load(state.repositories.helpers);
    final pw = await _readPassword(state);
    if (!mounted) return;
    setState(() {
      _useOther = s.useOtherAddress;
      _other.text = s.otherAddress;
      final imap = s.imap;
      if (imap != null) {
        _host.text = imap.host;
        _port.text = '${imap.port}';
        _user.text = imap.user;
        _security = imap.security;
      }
      _connected = imap != null && (pw ?? '').isNotEmpty;
    });
  }

  Future<String?> _readPassword(AppState state) async {
    try {
      return await state.mailCredentials.read(MailSlots.receive);
    } on Object {
      return null;
    }
  }

  String get _businessEmail =>
      AppScope.read(context).profile?.email.trim() ?? '';

  String get _address => _useOther ? _other.text.trim() : _businessEmail;

  MailServer get _manualServer => MailServer(
    host: _host.text.trim(),
    port: int.tryParse(_port.text.trim()) ?? 0,
    security: _security,
    user: _user.text.trim().isEmpty ? _address : _user.text.trim(),
  );

  Future<void> _save() async {
    final state = AppScope.read(context);
    final address = _address;
    if (!isMailAddress(address)) {
      setState(
        () => _error = _useOther
            ? 'Bitte eine gültige E-Mail-Adresse eintragen.'
            : 'In den Stammdaten steht keine gültige Geschäfts-E-Mail. '
                  'Bitte dort eintragen oder das Häkchen setzen.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = state.repositories.helpers;
      MailServer? server;
      final password = _password.text;
      if (password.isNotEmpty) {
        server = _manual && _host.text.trim().isNotEmpty
            ? _manualServer
            : (await state.mailAutoconfig.lookup(address))?.imap;
        if (server == null) {
          setState(() {
            _manual = true;
            if (_user.text.isEmpty) _user.text = address;
            _error =
                'Server nicht automatisch gefunden. Bitte die Angaben deines '
                'Anbieters eintragen (IMAP, meist Port 993).';
          });
          return;
        }
        await HelperMailInbox.test(
          server,
          password,
          connector: state.mailConnector,
        );
        await state.mailCredentials.write(MailSlots.receive, password);
      }
      final old = await MailReceiveSettings.load(repo);
      await MailReceiveSettings(
        useOtherAddress: _useOther,
        otherAddress: _other.text.trim(),
        imap: server ?? old.imap,
      ).save(repo);
      if (!mounted) return;
      if (server != null) {
        final explained = await repo.setting(
          MailSettingKeys.permissionsExplained,
        );
        if (explained == null && mounted) {
          await explainMailPermissions(context, helper: false);
          await repo.setSetting(MailSettingKeys.permissionsExplained, '1');
        }
        await state.configureMailBackground();
        await state.runMailSync();
      }
      if (!mounted) return;
      showSnack(
        context,
        server != null
            ? 'Verbunden. Neue Belege kommen von selbst in den Eingang.'
            : 'Adresse gespeichert.',
      );
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
    final business = _businessEmail;
    final provider = MailAutoconfig.providerOf(_address);
    return Scaffold(
      appBar: AppBar(title: const Text('Belege per E-Mail empfangen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (_error != null) ...[
            NoticeBanner(
              key: const Key('mail-error'),
              icon: Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              message: _error!,
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Mithelfer senden ihre Belege verschlüsselt an diese Adresse. '
            'Nur JeNi bucht auf diesem Gerät kann sie öffnen.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Empfangsadresse',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  business.isEmpty
                      ? 'Geschäfts-E-Mail: in den Stammdaten nicht eingetragen'
                      : 'Geschäfts-E-Mail: $business',
                ),
                CheckboxListTile(
                  key: const Key('mail-other'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  minTileHeight: 56,
                  value: _useOther,
                  onChanged: (v) => setState(() => _useOther = v ?? false),
                  title: const Text(
                    'Andere E-Mail-Adresse für den Empfang von Belegen',
                  ),
                ),
                if (_useOther)
                  TextField(
                    key: const Key('mail-other-address'),
                    controller: _other,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'E-Mail-Adresse für Belege',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Postfach lesen (nur lesen)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _connected
                      ? 'Verbunden. Zum Ändern neues Kennwort eintragen.'
                      : 'Die App sieht nur nach Mails mit „[JeNi-Beleg]“ im '
                            'Betreff, lädt den Anhang und lässt alles im '
                            'Postfach unverändert – nichts wird gelöscht, '
                            'verschoben oder als gelesen markiert.',
                ),
                const SizedBox(height: 12),
                PasswordField(
                  key: const Key('mail-password'),
                  controller: _password,
                  label: 'Kennwort oder App-Passwort',
                  helperText: 'Bleibt nur auf diesem Gerät gespeichert',
                ),
                const SizedBox(height: 12),
                AppPasswordGuide(provider: provider),
                const SizedBox(height: 8),
                ListTile(
                  key: const Key('mail-manual'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 48,
                  title: const Text('Server selbst eintragen'),
                  trailing: Icon(
                    _manual ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => setState(() => _manual = !_manual),
                ),
                if (_manual)
                  MailServerFields(
                    keyPrefix: 'imap',
                    title: 'Eingangsserver (IMAP)',
                    host: _host,
                    port: _port,
                    user: _user,
                    security: _security,
                    onSecurity: (s) => setState(() {
                      _security = s;
                      _port.text = s == MailSecurity.tls ? '993' : '143';
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('mail-save'),
          label: _password.text.isEmpty && _connected
              ? 'Speichern'
              : 'Verbinden und speichern',
          icon: Icons.check,
          busy: _busy,
          onPressed: _save,
        ),
      ),
    );
  }
}
